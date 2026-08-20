// lib/security_page.dart
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/background_video_service.dart';
import 'services/device_owner_service.dart';
import 'utils.dart';
import 'role_selection_screen.dart';

class SecurityPage extends StatefulWidget {
  final DeviceRole role;
  const SecurityPage({super.key, required this.role});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage>
    with WidgetsBindingObserver {
  late RtcEngine _engine;
  bool _engineCreated = false;

  // --- STATI DI SISTEMA ---
  bool _isReady = false;
  bool _isJoined = false;
  bool _isReconnecting = false;
  String? _initializationError;
  String _channelId = kChannelName;
  int? _streamId;
  bool _lockTaskStarted = false;

  // --- GESTIONE TELECAMERE ---
  final Set<int> _activeCameras = {};
  final Set<int> _selectedViewUids = {};
  final Map<int, String> _cameraNames = {};
  bool _viewerPresent = false;
  bool _selectedByViewer = false;
  final Set<int> _presentViewerUids = {};
  bool _wantViewerChannel = true;
  int _viewerApplyId = 0;
  Future<void> _viewerChannelQueue = Future.value();

  // Mappa per la qualità della rete (0: Sconosciuto, 1-2: Ottima, 3: Media, 4-6: Pessima)
  final Map<int, int> _networkQuality = {};
  final Map<int, int> _batteryLevels = {};
  final Map<int, bool> _remoteFlashOn = {};
  final Map<int, bool> _remoteFrontCamera = {};
  final Set<int> _listenEnabledUids = {};
  final Set<int> _remoteVideoReady = {};
  final Map<int, int> _remoteVideoViewGen = {};
  final Map<int, (int width, int height, int rotation)> _remoteVideoSizes = {};

  // --- UI STATES ---
  bool _ecoMode = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _batteryReportTimer;
  Timer? _viewerHeartbeatTimer;
  Timer? _viewerPresenceTimer;
  Timer? _screenOffTimer;
  int _screenOffSecondsLeft = 0;
  bool _displayAsleep = false;
  StreamSubscription<BatteryState>? _batteryStateSub;
  final Battery _battery = Battery();

  // --- HARDWARE STATES ---
  bool _isFlashOn = false;
  bool _useFrontCamera = false;
  bool _micEnabledByViewer = false;
  bool _viewerMicOn = false;
  bool _cameraCaptureOn = false;

  bool get isCamera => widget.role != DeviceRole.viewer;
  int get myUid => getUidFromRole(widget.role);
  bool get _isScreenFlashOn =>
      _isFlashOn && usesScreenAsFlash(frontCamera: _useFrontCamera);
  bool get _chromeVisible =>
      !_ecoMode &&
      !_displayAsleep &&
      (_showControls || shouldKeepSecurityChromeVisible(isCamera: isCamera));
  bool get _isTransmitting => isDataTransmitting(
        isCamera: isCamera,
        cameraPublishing: shouldPublishCameraVideo(
          viewerPresent: _viewerPresent,
          selectedByViewer: _selectedByViewer,
        ),
        viewerReceivingVideo:
            _selectedViewUids.any(_remoteVideoReady.contains),
      );
  bool get _hasLiveSelectedCamera =>
      _selectedViewUids.any(_activeCameras.contains);
  String get _viewerSelectionLabel {
    final selected = kCamUids.where(_selectedViewUids.contains).toList();
    if (selected.length == 1) return _cameraNames[selected.first] ?? '';
    return '${selected.length} camere';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!isCamera) {
      WakelockPlus.enable();
    }
    _loadCameraNames();
    _initAgora();
    _resetControlsTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _batteryReportTimer?.cancel();
    _viewerHeartbeatTimer?.cancel();
    _viewerPresenceTimer?.cancel();
    _screenOffTimer?.cancel();
    _batteryStateSub?.cancel();
    _wantViewerChannel = false;
    _viewerApplyId++;
    if (isCamera) BackgroundVideoService.stop();
    if (_viewerMicOn && _engineCreated) {
      unawaited(_setViewerMic(false));
    }
    if (_engineCreated) {
      final engine = _engine;
      final sendViewerLeave = !isCamera;
      _engineCreated = false;
      unawaited(
        _shutdownRtcEngine(engine, sendViewerLeave: sendViewerLeave),
      );
    }
    if (_ecoMode) {
      unawaited(_applyEcoSystemUi(false));
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isCamera) {
      if ((state == AppLifecycleState.inactive ||
              state == AppLifecycleState.paused) &&
          _isReady) {
        unawaited(BackgroundVideoService.start(live: _cameraCaptureOn));
      }
      if (state == AppLifecycleState.resumed) {
        if (_ecoMode) unawaited(_applyEcoSystemUi(true));
        _restartScreenOffCountdownIfNeeded();
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pauseViewerSession());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeViewerSession());
    }
  }

  // --- INIZIALIZZAZIONE ---

  Future<void> _loadCameraNames() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _useFrontCamera = prefs.getBool('cam_use_front') ?? false;
      for (final uid in kCamUids) {
        _cameraNames[uid] = prefs.getString('cam_name_$uid') ??
            'CAM ${kCamUids.indexOf(uid) + 1}';
      }
    });
    if (isCamera && _engineCreated) {
      unawaited(_applyCameraLensConfiguration());
    }
  }

  Future<bool> _saveCameraName(int uid, String newName) async {
    final normalizedName = normalizeCameraName(newName);
    final validationError = validateCameraName(normalizedName);
    if (validationError != null) {
      _showMediaError(validationError);
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cam_name_$uid', normalizedName);
    if (!mounted) return false;
    setState(() => _cameraNames[uid] = normalizedName);
    return true;
  }

  Future<void> _initAgora() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appId = prefs.getString('agora_app_id');
      if (appId == null || appId.isEmpty) {
        throw StateError('Inserisci l’Agora App ID prima di avviare.');
      }
      if (!mounted) return;
      _channelId = kChannelName;

      _engine = createAgoraRtcEngine();
      _engineCreated = true;
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      if (!mounted) return;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _isJoined = true;
              _isReconnecting = false;
            });
            unawaited(_onJoinedChannel());
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            _viewerHeartbeatTimer?.cancel();
            _viewerPresenceTimer?.cancel();
            setState(() {
              _isJoined = false;
              _activeCameras.clear();
              _networkQuality.clear();
              _batteryLevels.clear();
              _remoteFlashOn.clear();
              _remoteFrontCamera.clear();
              _remoteVideoReady.clear();
              _remoteVideoViewGen.clear();
              _remoteVideoSizes.clear();
              _presentViewerUids.clear();
              _viewerPresent = false;
              _selectedByViewer = false;
              _cameraCaptureOn = false;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            if (isRemoteViewerUid(remoteUid)) {
              _noteViewerActivity(remoteUid);
              return;
            }
            if (!kCamUids.contains(remoteUid)) return;
            setState(() => _activeCameras.add(remoteUid));
            if (!isCamera) {
              unawaited(_requestCameraStatus());
              unawaited(_broadcastWatchSelection());
              unawaited(_syncViewerVideoSubscriptions());
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            if (isRemoteViewerUid(remoteUid)) {
              _presentViewerUids.remove(remoteUid);
              if (_presentViewerUids.isEmpty) {
                _endViewerSession();
              }
              return;
            }
            setState(() {
              _activeCameras.remove(remoteUid);
              _networkQuality.remove(remoteUid);
              _batteryLevels.remove(remoteUid);
              _remoteFlashOn.remove(remoteUid);
              _remoteFrontCamera.remove(remoteUid);
              _listenEnabledUids.remove(remoteUid);
              _remoteVideoReady.remove(remoteUid);
              _remoteVideoViewGen.remove(remoteUid);
              _remoteVideoSizes.remove(remoteUid);
            });
          },
          onRemoteVideoStateChanged:
              (connection, remoteUid, state, reason, elapsed) {
            if (isCamera || !mounted) return;
            switch (state) {
              case RemoteVideoState.remoteVideoStateStarting:
              case RemoteVideoState.remoteVideoStateDecoding:
              case RemoteVideoState.remoteVideoStateFrozen:
                _setRemoteVideoReady(remoteUid, true);
              case RemoteVideoState.remoteVideoStateStopped:
              case RemoteVideoState.remoteVideoStateFailed:
                _setRemoteVideoReady(remoteUid, false);
            }
          },
          onFirstRemoteVideoDecoded:
              (connection, remoteUid, width, height, elapsed) {
            if (isCamera || !mounted) return;
            _setRemoteVideoReady(remoteUid, true);
            _setRemoteVideoSize(remoteUid, width, height);
          },
          onFirstRemoteVideoFrame:
              (connection, remoteUid, width, height, elapsed) {
            if (isCamera || !mounted) return;
            _setRemoteVideoReady(remoteUid, true);
            _setRemoteVideoSize(remoteUid, width, height);
          },
          onVideoSizeChanged:
              (connection, sourceType, uid, width, height, rotation) {
            if (isCamera || !mounted || uid == 0) return;
            _setRemoteVideoSize(uid, width, height, rotation);
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            if (state == ConnectionStateType.connectionStateReconnecting) {
              setState(() => _isReconnecting = true);
            } else if (state == ConnectionStateType.connectionStateConnected) {
              setState(() => _isReconnecting = false);
              if (isCamera) {
                unawaited(_syncCameraPublication());
              } else {
                unawaited(_requestCameraStatus());
                unawaited(_broadcastWatchSelection());
                unawaited(_syncViewerVideoSubscriptions());
              }
            }
          },
          onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
            if (remoteUid == 0) return;
            if (mounted) {
              setState(() => _networkQuality[remoteUid] = rxQuality.value());
            }
          },
          onStreamMessage:
              (connection, remoteUid, streamId, data, length, sentTs) {
            final message = String.fromCharCodes(data);
            if (isCamera) {
              _handleCameraStreamMessage(message, fromUid: remoteUid);
              return;
            }
            _handleViewerStreamMessage(message);
          },
        ),
      );

      // --- CONFIGURAZIONE VIDEO OTTIMIZZATA ---
      // 24 FPS = Fluidità cinematografica (migliore di 15, meno pesante di 30)
      await _engine
          .setVideoEncoderConfiguration(const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
        frameRate: 24,
        bitrate: 0, // Standard bitrate mode
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference
            .maintainFramerate, // Preferisce fluidità alla risoluzione se la rete cala
      ));

      await _engine.enableVideo();
      await _engine.enableAudio();
      if (!isCamera) {
        await _engine.enableAudioVolumeIndication(
            interval: 200, smooth: 3, reportVad: true);
      }
      await _engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      if (isCamera) {
        await _engine.enableLocalVideo(false);
        await _engine.enableLocalAudio(false);
        await _applyCameraLensConfiguration();
      }

      // Video in rete e sensore solo mentre un visore guarda questa cam.
      await _joinRtcChannel();

      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint("Init Error: $e");
      if (!mounted) return;
      setState(() {
        _isReady = false;
        _initializationError = e is StateError
            ? e.message.toString()
            : 'Impossibile avviare. Verifica App ID, rete e progetto Agora senza token.';
      });
    }
  }

  Future<void> _retryInitialization() async {
    if (_engineCreated) {
      try {
        await _engine.leaveChannel();
        await _engine.release();
      } catch (error) {
        debugPrint('RTC engine cleanup failed: $error');
      } finally {
        _engineCreated = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _isJoined = false;
      _isReady = false;
      _initializationError = null;
      _activeCameras.clear();
      _networkQuality.clear();
      _batteryLevels.clear();
      _remoteFlashOn.clear();
      _remoteFrontCamera.clear();
      _listenEnabledUids.clear();
      _remoteVideoReady.clear();
      _remoteVideoViewGen.clear();
      _remoteVideoSizes.clear();
      _presentViewerUids.clear();
      _viewerPresent = false;
      _selectedByViewer = false;
      _cameraCaptureOn = false;
      _wantViewerChannel = true;
    });
    _viewerHeartbeatTimer?.cancel();
    _viewerPresenceTimer?.cancel();
    await _initAgora();
  }

  ChannelMediaOptions get _channelMediaOptions => ChannelMediaOptions(
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: !isCamera,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      );

  Future<void> _joinRtcChannel() async {
    await _engine.joinChannel(
      token: '',
      channelId: kChannelName,
      uid: myUid,
      options: _channelMediaOptions,
    );
  }

  Future<void> _onJoinedChannel() async {
    await _createDataStream();
    if (!mounted) return;
    if (isCamera) {
      await BackgroundVideoService.start(live: false);
      await _startKioskForPairedCamera();
      await _syncCameraPowerMode();
      await _syncCameraPublication();
      await _startBatteryReporting();
      return;
    }
    _startViewerHeartbeat();
    await _engine.muteAllRemoteAudioStreams(true);
    await _requestCameraStatus();
    await _broadcastWatchSelection();
    await _syncViewerVideoSubscriptions();
  }

  void _setRemoteVideoReady(int uid, bool ready) {
    if (!kCamUids.contains(uid)) return;
    final alreadyReady = _remoteVideoReady.contains(uid);
    if (ready == alreadyReady) return;
    if (!mounted) {
      if (ready) {
        _remoteVideoReady.add(uid);
        _remoteVideoViewGen[uid] = (_remoteVideoViewGen[uid] ?? 0) + 1;
      } else {
        _remoteVideoReady.remove(uid);
      }
      return;
    }
    setState(() {
      if (ready) {
        _remoteVideoReady.add(uid);
        _remoteVideoViewGen[uid] = (_remoteVideoViewGen[uid] ?? 0) + 1;
      } else {
        _remoteVideoReady.remove(uid);
      }
    });
  }

  void _setRemoteVideoSize(int uid, int width, int height, [int rotation = 0]) {
    if (!kCamUids.contains(uid) || width < 2 || height < 2) return;
    final previous = _remoteVideoSizes[uid];
    if (previous != null &&
        previous.$1 == width &&
        previous.$2 == height &&
        previous.$3 == rotation) {
      return;
    }
    final wasPortrait = previous == null
        ? null
        : isOrientedVideoPortrait(
            width: previous.$1,
            height: previous.$2,
            rotation: previous.$3,
          );
    final nowPortrait = isOrientedVideoPortrait(
      width: width,
      height: height,
      rotation: rotation,
    );
    void apply() {
      _remoteVideoSizes[uid] = (width, height, rotation);
      if (wasPortrait != nowPortrait) {
        _remoteVideoViewGen[uid] = (_remoteVideoViewGen[uid] ?? 0) + 1;
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _handleCameraStreamMessage(String message, {required int fromUid}) {
    if (isViewerLeaveCommand(message)) {
      _presentViewerUids.remove(fromUid);
      if (_presentViewerUids.isEmpty) {
        _endViewerSession();
      }
      return;
    }
    if (isRemoteViewerUid(fromUid)) {
      _noteViewerActivity(fromUid);
    }
    final flashCommand = parseFlashCommand(message);
    if (flashCommand != null) {
      if (flashCommand.targetUid == null || flashCommand.targetUid == myUid) {
        unawaited(_applyRemoteFlashCommand(flashCommand.action));
      }
      return;
    }
    final listenCommand = parseListenCommand(message);
    if (listenCommand != null && listenCommand.targetUid == myUid) {
      unawaited(_setMicEnabledByViewer(listenCommand.enabled));
      return;
    }
    final lensCommand = parseLensCommand(message);
    if (lensCommand != null && lensCommand.targetUid == myUid) {
      unawaited(_setUseFrontCamera(lensCommand.lens == CameraLens.front));
      return;
    }
    if (isBatteryRequest(message)) {
      unawaited(_reportCameraStatusToViewer());
      return;
    }
    if (isWatchCommand(message)) {
      _setSelectedByViewer(parseWatchCommand(message).contains(myUid));
    }
  }

  void _handleViewerStreamMessage(String message) {
    final battery = parseBatteryReport(message);
    if (battery != null) {
      if (!mounted) return;
      setState(() => _batteryLevels[battery.$1] = battery.$2);
      return;
    }
    final flashState = parseFlashState(message);
    if (flashState != null) {
      if (!mounted) return;
      setState(() => _remoteFlashOn[flashState.$1] = flashState.$2);
      return;
    }
    final lensState = parseLensState(message);
    if (lensState != null) {
      if (!mounted) return;
      setState(() =>
          _remoteFrontCamera[lensState.$1] = lensState.$2 == CameraLens.front);
    }
  }

  Future<void> _startBatteryReporting() async {
    if (!isCamera) return;
    await _reportBatteryLevel();
    _batteryReportTimer?.cancel();
    _batteryReportTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _reportBatteryLevel());
    _batteryStateSub ??= _battery.onBatteryStateChanged.listen((_) {
      unawaited(_reportBatteryLevel());
    });
  }

  Future<void> _reportBatteryLevel() async {
    if (!isCamera || _streamId == null) return;
    try {
      final level = await _battery.batteryLevel;
      final data = Uint8List.fromList(
        encodeBatteryReport(myUid, level).codeUnits,
      );
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
    } catch (error) {
      debugPrint('Battery report failed: $error');
    }
  }

  Future<void> _broadcastFlashState() async {
    if (!isCamera || _streamId == null) return;
    try {
      final data = Uint8List.fromList(
        encodeFlashState(myUid, _isFlashOn).codeUnits,
      );
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
    } catch (error) {
      debugPrint('Flash state broadcast failed: $error');
    }
  }

  void _setViewerPresent(bool present) {
    final becamePresent = present && !_viewerPresent;
    final becameAbsent = !present && _viewerPresent;
    if (mounted) {
      setState(() {
        _viewerPresent = present;
        if (becameAbsent) _selectedByViewer = false;
      });
    } else {
      _viewerPresent = present;
      if (becameAbsent) _selectedByViewer = false;
    }
    unawaited(_syncCameraPublication());
    if (becamePresent) unawaited(_reportCameraStatusToViewer());
  }

  void _noteViewerActivity(int uid) {
    if (!isCamera) return;
    _presentViewerUids.add(uid);
    _restartViewerPresenceTimer();
    if (!_viewerPresent) _setViewerPresent(true);
  }

  void _restartViewerPresenceTimer() {
    _viewerPresenceTimer?.cancel();
    _viewerPresenceTimer = Timer(kViewerPresenceTimeout, _endViewerSession);
  }

  void _endViewerSession() {
    _viewerPresenceTimer?.cancel();
    _presentViewerUids.clear();
    if (!_viewerPresent && !_selectedByViewer && !_micEnabledByViewer) {
      unawaited(_syncCameraPublication());
      return;
    }
    if (mounted) {
      setState(() {
        _viewerPresent = false;
        _selectedByViewer = false;
      });
    } else {
      _viewerPresent = false;
      _selectedByViewer = false;
    }
    unawaited(_syncCameraPublication());
    unawaited(_setMicEnabledByViewer(false));
    if (_isFlashOn) unawaited(_setLocalFlash(false));
  }

  void _startViewerHeartbeat() {
    if (isCamera) return;
    _viewerHeartbeatTimer?.cancel();
    _viewerHeartbeatTimer =
        Timer.periodic(kViewerHeartbeatInterval, (_) {
      unawaited(_broadcastWatchSelection());
    });
  }

  void _stopViewerHeartbeat() {
    _viewerHeartbeatTimer?.cancel();
    _viewerHeartbeatTimer = null;
  }

  Future<void> _sendViewerLeave() async {
    if (isCamera || !_engineCreated) return;
    try {
      await _sendChannelMessage(kViewerLeaveCommand);
    } catch (error) {
      debugPrint('Viewer leave signal failed: $error');
    }
  }

  Future<void> _shutdownRtcEngine(
    RtcEngine engine, {
    required bool sendViewerLeave,
  }) async {
    if (sendViewerLeave) {
      try {
        final streamId = _streamId;
        if (streamId != null) {
          final data = Uint8List.fromList(kViewerLeaveCommand.codeUnits);
          await engine.sendStreamMessage(
            streamId: streamId,
            data: data,
            length: data.length,
          );
        }
      } catch (error) {
        debugPrint('Viewer leave on shutdown failed: $error');
      }
    }
    try {
      await engine.leaveChannel();
    } catch (error) {
      debugPrint('RTC leave on shutdown failed: $error');
    }
    try {
      await engine.release();
    } catch (error) {
      debugPrint('RTC release failed: $error');
    }
  }

  Future<void> _reportCameraStatusToViewer() async {
    if (!isCamera) return;
    await _reportBatteryLevel();
    await _broadcastFlashState();
    await _broadcastLensState();
  }

  Future<void> _requestCameraStatus() async {
    if (isCamera || !_engineCreated) return;
    try {
      await _sendChannelMessage(kBatteryRequestCommand);
    } catch (error) {
      debugPrint('Battery request failed: $error');
    }
  }

  void _setSelectedByViewer(bool selected) {
    if (mounted) {
      setState(() => _selectedByViewer = selected);
    } else {
      _selectedByViewer = selected;
    }
    unawaited(_syncCameraPublication());
  }

  Future<void> _syncCameraPublication() async {
    if (!isCamera || !_engineCreated || !_isJoined) return;
    final shouldPublishVideo = shouldPublishCameraVideo(
      viewerPresent: _viewerPresent,
      selectedByViewer: _selectedByViewer,
    );
    final shouldPublishMic = shouldPublishVideo && _micEnabledByViewer;
    try {
      if (shouldPublishVideo) {
        await _setCameraCapture(true);
      }
      await _engine.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishCameraTrack: shouldPublishVideo,
          publishMicrophoneTrack: shouldPublishMic,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      if (!shouldPublishVideo) {
        await _setCameraCapture(false);
      }
      await _engine.enableLocalAudio(shouldPublishMic);
    } catch (error) {
      debugPrint('Camera publication sync failed: $error');
    }
  }

  Future<void> _setCameraCapture(bool on) async {
    if (!isCamera || !_engineCreated) return;
    if (_cameraCaptureOn == on) return;
    try {
      if (on) {
        await _applyCameraLensConfiguration();
        await _engine.enableLocalVideo(true);
        if (shouldShowLocalCameraPreview(
          capturing: true,
          ecoMode: _ecoMode,
          displayAsleep: _displayAsleep,
        )) {
          await _engine.startPreview();
        }
      } else {
        if (_isFlashOn) await _setLocalFlash(false);
        await _engine.stopPreview();
        await _engine.enableLocalVideo(false);
      }
      _cameraCaptureOn = on;
      await _syncCameraPowerMode();
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Camera capture toggle failed: $error');
    }
  }

  Future<void> _syncCameraPowerMode() async {
    if (!isCamera) return;
    final keepScreenOn = shouldKeepCameraAwake(
      capturing: _cameraCaptureOn,
      ecoMode: _ecoMode,
      screenFlashOn: _isScreenFlashOn,
    );
    await _syncScreenOffCountdown(keepScreenOn: keepScreenOn);
    try {
      if (keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      await BackgroundVideoService.start(live: _cameraCaptureOn);
      await DeviceOwnerService().setCameraPowerSave(
        !keepScreenOn,
        screenTimeout: kCameraStandbyScreenTimeout,
      );
      if (_isScreenFlashOn) {
        await DeviceOwnerService().setScreenFlashlight(true);
      }
    } catch (error) {
      debugPrint('Camera power mode failed: $error');
    }
  }

  Future<void> _syncScreenOffCountdown({required bool keepScreenOn}) async {
    if (keepScreenOn) {
      await _stopScreenOffCountdown();
      return;
    }
    if (_ecoMode) {
      if (!_displayAsleep) unawaited(_enterDisplayAsleepNow());
      return;
    }
    if (_screenOffTimer == null && !_displayAsleep) {
      _startScreenOffCountdown();
    }
  }

  Future<void> _enterDisplayAsleepNow() async {
    if (_isScreenFlashOn) return;
    _screenOffTimer?.cancel();
    _screenOffTimer = null;
    if (mounted) {
      setState(() {
        _screenOffSecondsLeft = 0;
        _displayAsleep = true;
      });
    } else {
      _screenOffSecondsLeft = 0;
      _displayAsleep = true;
    }
    await _syncLocalPreview();
    await _applyDisplayAsleep(true);
  }

  Future<void> _syncLocalPreview() async {
    if (!isCamera || !_engineCreated || !_cameraCaptureOn) return;
    try {
      if (shouldShowLocalCameraPreview(
        capturing: true,
        ecoMode: _ecoMode,
        displayAsleep: _displayAsleep,
      )) {
        await _engine.startPreview();
      } else {
        await _engine.stopPreview();
      }
    } catch (error) {
      debugPrint('Local preview sync failed: $error');
    }
  }

  void _restartScreenOffCountdownIfNeeded() {
    if (!isCamera) return;
    if (shouldKeepCameraAwake(
      capturing: _cameraCaptureOn,
      ecoMode: _ecoMode,
      screenFlashOn: _isScreenFlashOn,
    )) {
      return;
    }
    _startScreenOffCountdown();
  }

  Future<void> _stopScreenOffCountdown() async {
    _screenOffTimer?.cancel();
    _screenOffTimer = null;
    final wasAsleep = _displayAsleep;
    if (_screenOffSecondsLeft == 0 && !wasAsleep) return;
    if (mounted) {
      setState(() {
        _screenOffSecondsLeft = 0;
        _displayAsleep = false;
      });
    } else {
      _screenOffSecondsLeft = 0;
      _displayAsleep = false;
    }
    if (wasAsleep) {
      await _applyDisplayAsleep(false);
      unawaited(_syncLocalPreview());
    }
  }

  void _startScreenOffCountdown() {
    _screenOffTimer?.cancel();
    final wasAsleep = _displayAsleep;
    final seconds = kCameraStandbyScreenTimeout.inSeconds;
    if (mounted) {
      setState(() {
        _screenOffSecondsLeft = seconds;
        _displayAsleep = false;
      });
    } else {
      _screenOffSecondsLeft = seconds;
      _displayAsleep = false;
    }
    if (wasAsleep) unawaited(_applyDisplayAsleep(false));
    unawaited(_syncLocalPreview());
    _screenOffTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_screenOffSecondsLeft <= 1) {
        timer.cancel();
        _screenOffTimer = null;
        setState(() {
          _screenOffSecondsLeft = 0;
          _displayAsleep = true;
        });
        unawaited(_syncLocalPreview());
        unawaited(_applyDisplayAsleep(true));
        return;
      }
      setState(() => _screenOffSecondsLeft -= 1);
    });
  }

  Future<void> _applyDisplayAsleep(bool asleep) async {
    if (!isCamera) return;
    if (asleep && _isScreenFlashOn) return;
    try {
      if (asleep) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setSystemUIOverlayStyle(_ecoSystemUi);
        await DeviceOwnerService().blankDisplay(true);
        return;
      }
      await DeviceOwnerService().blankDisplay(false);
      if (_ecoMode) {
        await _applyEcoSystemUi(true);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(_defaultSystemUi);
      }
    } catch (error) {
      debugPrint('Display sleep failed: $error');
    }
  }

  Future<void> _applyCameraLensConfiguration() async {
    if (!isCamera || !_engineCreated) return;
    try {
      await _engine.setCameraCapturerConfiguration(
        CameraCapturerConfiguration(
          cameraDirection: _useFrontCamera
              ? CameraDirection.cameraFront
              : CameraDirection.cameraRear,
        ),
      );
    } catch (error) {
      debugPrint('Camera lens configuration failed: $error');
    }
  }

  Future<void> _setMicEnabledByViewer(bool enabled) async {
    if (!isCamera) return;
    if (enabled) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }
    if (!mounted) return;
    setState(() => _micEnabledByViewer = enabled);
    await _syncCameraPublication();
  }

  void _toggleViewerCamera(int uid) {
    final wasSelected = _selectedViewUids.contains(uid);
    setState(() {
      if (!_selectedViewUids.add(uid)) {
        _selectedViewUids.remove(uid);
        _remoteVideoReady.remove(uid);
      }
    });
    if (wasSelected && _listenEnabledUids.contains(uid)) {
      unawaited(_sendListenCommand(uid, false));
    }
    HapticFeedback.selectionClick();
    unawaited(_broadcastWatchSelection());
    unawaited(_syncViewerVideoSubscriptions());
  }

  Future<void> _syncViewerVideoSubscriptions() async {
    if (isCamera || !_engineCreated || !_isJoined) return;
    for (final uid in kCamUids) {
      final subscribe = _selectedViewUids.contains(uid);
      try {
        await _engine.muteRemoteVideoStream(uid: uid, mute: !subscribe);
      } catch (error) {
        debugPrint('Remote video subscribe failed for $uid: $error');
      }
    }
  }

  Future<void> _broadcastWatchSelection() async {
    if (isCamera || !_engineCreated) return;
    try {
      await _sendChannelMessage(encodeWatchCommand(_selectedViewUids));
    } catch (error) {
      debugPrint('Watch command failed: $error');
    }
  }

  Future<void> _pauseViewerSession() async {
    _wantViewerChannel = false;
    _scheduleViewerChannelApply();
  }

  Future<void> _resumeViewerSession() async {
    _wantViewerChannel = true;
    _scheduleViewerChannelApply();
  }

  void _scheduleViewerChannelApply() {
    if (isCamera || !_engineCreated) return;
    final id = ++_viewerApplyId;
    _viewerChannelQueue =
        _viewerChannelQueue.catchError((Object _) {}).then((_) async {
      if (id != _viewerApplyId || !_engineCreated) return;
      try {
        if (_wantViewerChannel) {
          if (!_isReady) return;
          await _joinRtcChannel();
        } else {
          _stopViewerHeartbeat();
          await _sendViewerLeave();
          await _engine.leaveChannel();
        }
      } catch (error) {
        debugPrint('Viewer channel apply failed: $error');
        if (_wantViewerChannel && mounted && id == _viewerApplyId) {
          _showMediaError('Impossibile riprendere il monitoraggio.');
        }
      }
    });
  }

  // --- LOGICA DI CONTROLLO ---

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
  }

  Future<void> _applyRemoteFlashCommand(FlashAction action) async {
    switch (action) {
      case FlashAction.on:
        await _setLocalFlash(true);
      case FlashAction.off:
        await _setLocalFlash(false);
      case FlashAction.toggle:
        await _toggleLocalFlash();
    }
  }

  Future<void> _setLocalFlash(bool on) async {
    if (!isCamera) return;
    if (on && !_cameraCaptureOn) return;
    final previous = _isFlashOn;
    if (mounted) {
      setState(() => _isFlashOn = on);
    } else {
      _isFlashOn = on;
    }
    try {
      await _applyFlashOutput();
      await _broadcastFlashState();
    } catch (e) {
      if (mounted) {
        setState(() => _isFlashOn = previous);
      } else {
        _isFlashOn = previous;
      }
      debugPrint('Flash Error: $e');
      _showMediaError('Impossibile aggiornare la torcia.');
      try {
        await _applyFlashOutput();
      } catch (error) {
        debugPrint('Flash revert failed: $error');
      }
    }
  }

  /// Posteriore: LED. Frontale: schermo bianco a luminosità massima.
  Future<void> _applyFlashOutput() async {
    if (!isCamera) return;
    if (usesScreenAsFlash(frontCamera: _useFrontCamera)) {
      try {
        await _engine.setCameraTorchOn(false);
      } catch (_) {}
      if (!_isFlashOn) {
        await DeviceOwnerService().setScreenFlashlight(
          false,
          restoreSystemBars: !_ecoMode && !_displayAsleep,
        );
      }
      await _syncCameraPowerMode();
      return;
    }
    await DeviceOwnerService().setScreenFlashlight(
      false,
      restoreSystemBars: !_ecoMode && !_displayAsleep,
    );
    await _engine.setCameraTorchOn(_isFlashOn);
    await _syncCameraPowerMode();
  }

  Future<void> _toggleLocalFlash() async {
    await _setLocalFlash(!_isFlashOn);
  }

  Future<void> _switchCamera() async {
    await _setUseFrontCamera(!_useFrontCamera);
  }

  Future<void> _setUseFrontCamera(bool front) async {
    if (!isCamera) return;
    if (_useFrontCamera == front) {
      await _broadcastLensState();
      return;
    }
    final previous = _useFrontCamera;
    if (mounted) {
      setState(() => _useFrontCamera = front);
    } else {
      _useFrontCamera = front;
    }
    try {
      if (_cameraCaptureOn) {
        await _engine.switchCamera();
        await _applyFlashOutput();
      } else {
        await _applyCameraLensConfiguration();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cam_use_front', front);
      await _broadcastLensState();
    } catch (error) {
      if (mounted) {
        setState(() => _useFrontCamera = previous);
      } else {
        _useFrontCamera = previous;
      }
      debugPrint('Switch camera error: $error');
      _showMediaError('Impossibile cambiare fotocamera.');
    }
  }

  Future<void> _broadcastLensState() async {
    if (!isCamera || _streamId == null) return;
    try {
      final data = Uint8List.fromList(
        encodeLensState(
          myUid,
          _useFrontCamera ? CameraLens.front : CameraLens.rear,
        ).codeUnits,
      );
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
    } catch (error) {
      debugPrint('Lens state broadcast failed: $error');
    }
  }

  Future<void> _createDataStream() async {
    try {
      final streamId = await _engine.createDataStream(
        const DataStreamConfig(syncWithAudio: false, ordered: true),
      );
      _streamId = streamId >= 0 ? streamId : null;
    } catch (error) {
      debugPrint('Data stream create failed: $error');
      _streamId = null;
    }
  }

  Future<void> _ensureDataStream() async {
    if (_streamId != null) return;
    await _createDataStream();
  }

  Future<void> _sendChannelMessage(String message) async {
    await _ensureDataStream();
    if (_streamId == null) {
      throw StateError('Data stream unavailable');
    }
    final data = Uint8List.fromList(message.codeUnits);
    try {
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
    } catch (error) {
      _streamId = null;
      await _ensureDataStream();
      if (_streamId == null) rethrow;
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
    }
  }

  Future<void> _sendRemoteFlash(int uid, FlashAction action) async {
    if (!_activeCameras.contains(uid)) return;
    try {
      await _sendChannelMessage(encodeFlashCommand(uid, action));
      HapticFeedback.selectionClick();
      if (action == FlashAction.toggle) {
        final current = _remoteFlashOn[uid] ?? false;
        if (mounted) setState(() => _remoteFlashOn[uid] = !current);
      } else if (mounted) {
        setState(() => _remoteFlashOn[uid] = action == FlashAction.on);
      }
    } catch (error) {
      debugPrint('Remote torch command failed: $error');
      _showMediaError('Impossibile inviare il comando torcia.');
    }
  }

  Future<void> _sendListenCommand(int uid, bool enabled) async {
    if (!_activeCameras.contains(uid)) return;
    try {
      await _sendChannelMessage(encodeListenCommand(uid, enabled));
      await _engine.muteRemoteAudioStream(uid: uid, mute: !enabled);
      if (!mounted) return;
      setState(() {
        if (enabled) {
          _listenEnabledUids.add(uid);
        } else {
          _listenEnabledUids.remove(uid);
        }
      });
      HapticFeedback.selectionClick();
    } catch (error) {
      debugPrint('Listen command failed: $error');
      _showMediaError('Impossibile aggiornare l’audio della telecamera.');
    }
  }

  Future<void> _toggleCameraListen(int uid) async {
    final enable = !_listenEnabledUids.contains(uid);
    await _sendListenCommand(uid, enable);
  }

  Future<void> _toggleCameraFlash(int uid) async {
    final isOn = _remoteFlashOn[uid] ?? false;
    await _sendRemoteFlash(uid, isOn ? FlashAction.off : FlashAction.on);
  }

  Future<void> _toggleCameraLens(int uid) async {
    final nextFront = !(_remoteFrontCamera[uid] ?? false);
    await _sendLensCommand(
      uid,
      nextFront ? CameraLens.front : CameraLens.rear,
    );
  }

  Future<void> _sendLensCommand(int uid, CameraLens lens) async {
    if (!_activeCameras.contains(uid)) return;
    try {
      await _sendChannelMessage(encodeLensCommand(uid, lens));
      HapticFeedback.selectionClick();
      if (mounted) setState(() => _remoteFrontCamera[uid] = lens == CameraLens.front);
    } catch (error) {
      debugPrint('Remote lens command failed: $error');
      _showMediaError('Impossibile cambiare fotocamera.');
    }
  }

  Future<void> _setViewerMic(bool enabled) async {
    if (!_engineCreated || !_isJoined) return;
    if (enabled) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showMediaError('Permesso microfono necessario per parlare.');
        return;
      }
    }
    try {
      if (enabled) {
        await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: false,
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
        await _engine.muteLocalAudioStream(false);
      } else {
        await _engine.muteLocalAudioStream(true);
        await _engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: false,
            publishMicrophoneTrack: false,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _viewerMicOn = enabled);
    } catch (error) {
      debugPrint('Viewer mic error: $error');
      _showMediaError('Impossibile aggiornare il microfono.');
    }
  }

  Future<void> _toggleViewerMic() async {
    await _setViewerMic(!_viewerMicOn);
  }

  Future<void> _startKioskForPairedCamera() async {
    if (!isCamera || _lockTaskStarted || !mounted) return;

    try {
      final deviceOwner = DeviceOwnerService();
      if (!await deviceOwner.canStartLockTask()) return;
      await deviceOwner.startLockTask();
      if (mounted) _lockTaskStarted = true;
    } catch (error) {
      // Kiosk is optional until the device has completed Device Owner
      // provisioning; streaming must remain available on ordinary devices.
      debugPrint('Lock Task not activated: $error');
    }
  }

  Future<void> _toggleEcoMode(bool enable) async {
    if (!isCamera && enable) return;
    try {
      if (!mounted) return;
      setState(() {
        _ecoMode = enable;
        _showControls = !enable;
      });
      await _applyEcoSystemUi(enable);
      await _syncCameraPowerMode();
      if (!enable) {
        if (mounted) setState(() => _showControls = true);
        _resetControlsTimer();
      }
    } catch (error) {
      debugPrint('Eco mode error: $error');
      _showMediaError('Impossibile aggiornare la modalità risparmio.');
    }
  }

  static const _ecoSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.black,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );

  static const _defaultSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  Future<void> _applyEcoSystemUi(bool enable) async {
    if (enable) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(_ecoSystemUi);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(_defaultSystemUi);
    }
    await DeviceOwnerService().setEcoChrome(enable);
  }

  void _showMediaError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _onSecurityScreenTap() {
    if (_ecoMode) return;
    if (shouldKeepSecurityChromeVisible(isCamera: isCamera)) return;
    setState(() => _showControls = !_showControls);
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Schermata sicurezza',
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onDoubleTap: isCamera ? () => _toggleEcoMode(false) : null,
          onTapDown: isCamera && !_ecoMode
              ? (_) => _restartScreenOffCountdownIfNeeded()
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoArea(),
              if (isCamera && _displayAsleep)
                const ColoredBox(color: Colors.black),
              if (!isCamera)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _onSecurityScreenTap,
                  ),
                ),
              if (_isReconnecting && !_ecoMode && !_displayAsleep)
                Container(
                  color: Colors.black54,
                  child: const Center(
                      child: Text("Riconnessione in corso...",
                          style: TextStyle(color: Colors.white))),
                ),
              if (!_ecoMode && !isCamera) _buildViewerDock(),
              if (isCamera && _ecoMode && !_displayAsleep) _buildEcoOverlay(),
              if (isCamera && _isScreenFlashOn)
                const Positioned.fill(
                  child: ColoredBox(color: Colors.white),
                ),
              if (!_ecoMode && !_displayAsleep) _buildTopBar(),
              if (!_ecoMode && isCamera && !_displayAsleep)
                _buildBottomControls(),
            ],
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_ecoMode || _displayAsleep) ? _ecoSystemUi : _defaultSystemUi,
      child: (_ecoMode || _displayAsleep)
          ? MediaQuery.removeViewPadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: screen,
            )
          : screen,
    );
  }

  Widget _buildVideoArea() {
    if (_initializationError != null) {
      return _buildRecoveryView(_initializationError!);
    }
    if (!_isReady) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (isCamera) {
      if (shouldShowLocalCameraPreview(
        capturing: _cameraCaptureOn,
        ecoMode: _ecoMode,
        displayAsleep: _displayAsleep,
      )) {
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: const VideoCanvas(uid: 0),
            useAndroidSurfaceView: true,
          ),
        );
      }
      if (_ecoMode || _displayAsleep) {
        return const ColoredBox(color: Colors.black);
      }
      return _buildCameraStandbyView();
    }
    if (_selectedViewUids.isEmpty) {
      return _buildSelectCamerasView();
    }
    return _buildViewerGrid();
  }

  Widget _buildCameraStandbyView() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Color(0x4DFFFFFF), size: 60),
            const SizedBox(height: 20),
            const Text(
              'STANDBY',
              style: TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              cameraStandbyScreenOffMessage(_screenOffSecondsLeft),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectCamerasView() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, color: Color(0x4DFFFFFF), size: 60),
            SizedBox(height: 20),
            Text(
              "Seleziona una o più camere",
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 16),
            ),
            SizedBox(height: 10),
            Text("Solo le camere scelte trasmettono video",
                style: TextStyle(color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerGrid() {
    final uids = kCamUids.where(_selectedViewUids.contains).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = viewerGridColumnCount(
          selectedCount: uids.length,
          landscape: constraints.maxWidth > constraints.maxHeight,
        );
        final rows = (uids.length / columns).ceil();
        return Column(
          children: [
            for (var row = 0; row < rows; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < columns; col++)
                      if (row * columns + col < uids.length)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: _buildRemoteTile(uids[row * columns + col]),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRemoteTile(int uid) {
    final isLive = _activeCameras.contains(uid);
    final name = _cameraNames[uid] ?? 'CAM';
    final hasVideo = _remoteVideoReady.contains(uid);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF101010),
          child: isLive ? _buildRemoteVideoView(uid) : _buildTileWaiting(name),
        ),
        if (isLive && !hasVideo)
          const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteVideoView(int uid) {
    final size = _remoteVideoSizes[uid];
    final oriented = size == null
        ? null
        : orientedVideoSize(
            width: size.$1,
            height: size.$2,
            rotation: size.$3,
          );
    final portrait = oriented != null && oriented.height > oriented.width;
    final video = AgoraVideoView(
      key: ValueKey(
        'remote-$uid-${_remoteVideoViewGen[uid] ?? 0}-${portrait ? 'p' : 'l'}',
      ),
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(
          uid: uid,
          sourceType: VideoSourceType.videoSourceRemote,
          renderMode: RenderModeType.renderModeFit,
        ),
        connection: RtcConnection(channelId: _channelId, localUid: myUid),
        useAndroidSurfaceView: true,
      ),
    );
    if (oriented == null) return video;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: oriented.width / oriented.height,
          child: video,
        ),
      ),
    );
  }

  Color _batteryColor(int level) {
    if (level >= 50) return Colors.greenAccent;
    if (level >= 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildTileWaiting(String name) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam,
              color: Colors.white.withValues(alpha: 0.25), size: 36),
          const SizedBox(height: 8),
          Text(
            "In attesa di $name",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Telecamera non disponibile',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh),
              label: const Text('RIPROVA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: _chromeVisible ? 0 : -120,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: Container(
          height: 110,
          padding: const EdgeInsets.fromLTRB(20, 50, 12, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCamera
                          ? (_isJoined
                              ? (shouldPublishCameraVideo(
                                      viewerPresent: _viewerPresent,
                                      selectedByViewer: _selectedByViewer)
                                  ? "TRASMISSIONE ATTIVA"
                                  : (_viewerPresent
                                      ? "NON SELEZIONATA"
                                      : "IN ATTESA VISORE"))
                              : "TELECAMERA DISCONNESSA")
                          : (_isJoined
                              ? "MONITORAGGIO LIVE"
                              : "VISORE DISCONNESSO"),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    if (!isCamera && _selectedViewUids.isNotEmpty)
                      Text(
                        _viewerSelectionLabel,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen())),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14, right: 8),
                child: _StatusDot(isTransmitting: _isTransmitting),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _chromeVisible ? 30 : -200,
      left: 15,
      right: 15,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 2)
          ],
        ),
        child: _buildCameraButtons(),
        ),
      ),
    );
  }

  Widget _buildViewerDock() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: 12,
      right: 12,
      bottom: _chromeVisible ? 8 + bottomInset : -280,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: _buildViewerInterface(),
          ),
        ),
      ),
    );
  }

  // --- CONTROLLI VISORE MIGLIORATI ---
  Widget _buildViewerInterface() {
    const cameraUids = kCamUids;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 132,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cameraUids.length,
            itemBuilder: (ctx, index) {
              final uid = cameraUids[index];
              return _buildViewerCameraChip(uid);
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: _hasLiveSelectedCamera ? _toggleViewerMic : null,
            icon: Icon(
              _viewerMicOn ? Icons.mic : Icons.mic_none,
              color: !_hasLiveSelectedCamera
                  ? Colors.white24
                  : (_viewerMicOn ? Colors.redAccent : Colors.white),
            ),
            label: Text(
              _viewerMicOn ? 'Parlando' : 'Parla',
              style: TextStyle(
                color: !_hasLiveSelectedCamera
                    ? Colors.white24
                    : (_viewerMicOn ? Colors.redAccent : Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerCameraChip(int uid) {
    final isActive = _activeCameras.contains(uid);
    final isSelected = _selectedViewUids.contains(uid);
    final battery = _batteryLevels[uid];
    final flashOn = _remoteFlashOn[uid] ?? false;
    final frontCamera = _remoteFrontCamera[uid] ?? false;
    final listenOn = _listenEnabledUids.contains(uid);
    final controlsEnabled = isActive && isSelected;
    final quality = _networkQuality[uid] ?? 0;
    final qualityColor = (quality > 0 && quality <= 2)
        ? Colors.green
        : (quality <= 4 && quality > 0)
            ? Colors.orange
            : (isActive ? Colors.red : Colors.grey);

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${_cameraNames[uid] ?? 'Camera'}. ${isActive ? 'Connessa' : 'Disconnessa'}${battery != null ? '. Batteria $battery%' : ''}',
      hint:
          'Tocca per aggiungere o togliere dalla griglia, tieni premuto per rinominare',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        width: 118,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected
                  ? Colors.blueAccent
                  : (isActive ? Colors.white12 : Colors.transparent),
              width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _toggleViewerCamera(uid),
              onLongPress: () => _showRenameDialog(uid),
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Icon(Icons.videocam,
                            color: isActive ? Colors.white : Colors.white24,
                            size: 26),
                        if (isActive)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: qualityColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 1)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cameraNames[uid] ?? "CAM",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white38,
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isActive && battery != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.battery_std,
                              size: 10, color: _batteryColor(battery)),
                          const SizedBox(width: 2),
                          Text(
                            '$battery%',
                            style: TextStyle(
                              color: _batteryColor(battery),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IgnorePointer(
                  ignoring: !controlsEnabled,
                  child: _TileControlButton(
                    icon: flashOn ? Icons.flash_on : Icons.flash_off,
                    color: !controlsEnabled
                        ? Colors.white24
                        : (flashOn ? Colors.yellow : Colors.white70),
                    tooltip: flashOn ? 'Spegni flash' : 'Accendi flash',
                    onTap: () => _toggleCameraFlash(uid),
                  ),
                ),
                const SizedBox(width: 3),
                IgnorePointer(
                  ignoring: !controlsEnabled,
                  child: _TileControlButton(
                    icon: listenOn ? Icons.volume_up : Icons.volume_off,
                    color: !controlsEnabled
                        ? Colors.white24
                        : (listenOn ? Colors.greenAccent : Colors.white70),
                    tooltip: listenOn
                        ? 'Disattiva audio camera'
                        : 'Ascolta camera',
                    onTap: () => _toggleCameraListen(uid),
                  ),
                ),
                const SizedBox(width: 3),
                IgnorePointer(
                  ignoring: !controlsEnabled,
                  child: _TileControlButton(
                    icon: frontCamera
                        ? Icons.photo_camera_front
                        : Icons.photo_camera_back,
                    color: !controlsEnabled
                        ? Colors.white24
                        : (frontCamera ? Colors.lightBlueAccent : Colors.white70),
                    tooltip: frontCamera
                        ? 'Usa fotocamera posteriore'
                        : 'Usa fotocamera frontale',
                    onTap: () => _toggleCameraLens(uid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTROLLI TELECAMERA ---
  Widget _buildCameraButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: _useFrontCamera
              ? Icons.photo_camera_front
              : Icons.photo_camera_back,
          isActive: true,
          color: Colors.blueAccent,
          onTap: _switchCamera,
          label: _useFrontCamera ? "Frontale" : "Posteriore",
        ),
        _ActionButton(
          icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
          isActive: true,
          color: _isFlashOn ? Colors.yellow : Colors.white,
          onTap: _toggleLocalFlash,
          label: "Flash",
        ),
        _ActionButton(
          icon: Icons.eco,
          isActive: true,
          color: Colors.greenAccent,
          onTap: () => _toggleEcoMode(true),
          label: "Eco",
        ),
      ],
    );
  }

  Widget _buildEcoOverlay() {
    const ink = Color(0xFF0A0A0A);
    const countdownInk = Color(0xFF2E2E2E);
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, color: ink, size: 64),
            const SizedBox(height: 16),
            const Text(
              'ECO',
              style: TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraCaptureOn
                  ? 'Schermo in risparmio · trasmissione attiva'
                  : 'Schermo in risparmio · in attesa visore',
              style: const TextStyle(color: ink, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Lo schermo si spegnerà fra ${_screenOffSecondsLeft}s',
              style: const TextStyle(color: countdownInk, fontSize: 12),
            ),
            const SizedBox(height: 32),
            const Text(
              'Doppio tocco per sbloccare',
              style: TextStyle(color: ink, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGS ---
  void _showRenameDialog(int uid) {
    TextEditingController controller =
        TextEditingController(text: _cameraNames[uid]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Rinomina Camera",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Es: Ingresso",
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Annulla", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final saved = await _saveCameraName(uid, controller.text);
              if (saved && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Salva",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// --- WIDGETS AUSILIARI ---

class _StatusDot extends StatelessWidget {
  final bool isTransmitting;
  const _StatusDot({required this.isTransmitting});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isTransmitting
          ? 'Trasmissione dati attiva'
          : 'Nessuna trasmissione dati',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isTransmitting ? Colors.greenAccent : Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: (isTransmitting ? Colors.green : Colors.red)
                      .withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2)
            ],
          ),
        ),
      ),
    );
  }
}

class _TileControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _TileControlButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  const _ActionButton(
      {required this.icon,
      required this.isActive,
      required this.color,
      required this.onTap,
      this.label});

  @override
  Widget build(BuildContext context) {
    final actionLabel = label ?? icon.toString();
    return Semantics(
      button: true,
      enabled: isActive,
      label: actionLabel,
      child: InkWell(
        onTap: isActive ? onTap : null,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                  color:
                      isActive ? color.withValues(alpha: 0.5) : Colors.white12),
            ),
            child:
                Icon(icon, color: isActive ? color : Colors.white24, size: 26),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(label!,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]
        ],
        ),
      ),
    );
  }
}
