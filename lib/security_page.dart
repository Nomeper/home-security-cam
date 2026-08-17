// lib/security_page.dart
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _selectedViewUid = kCamUids[0];
  final Map<int, String> _cameraNames = {};

  // Mappa per la qualità della rete (0: Sconosciuto, 1-2: Ottima, 3: Media, 4-6: Pessima)
  final Map<int, int> _networkQuality = {};

  // --- UI STATES ---
  bool _ecoMode = false;
  bool _showControls = true;
  Timer? _controlsTimer;

  // --- HARDWARE STATES ---
  bool _isFlashOn = false;
  bool _audioEnabled = false;

  bool get isCamera => widget.role != DeviceRole.viewer;
  int get myUid => getUidFromRole(widget.role);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _loadCameraNames();
    _initAgora();
    _resetControlsTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    if (isCamera) BackgroundVideoService.stop();
    if (_engineCreated) {
      _engine.leaveChannel();
      _engine.release();
      _engineCreated = false;
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isCamera) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _handleCameraBackground();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCameraAfterBackground();
    }
  }

  Future<void> _handleCameraBackground() async {
    if (!_isReady) return;
    if (BackgroundVideoService.isAndroid) {
      await BackgroundVideoService.start();
      return;
    }

    // iOS does not permit continuous camera-video capture in background.
    // Stop the local preview and publication to avoid an ambiguous capture state.
    await _engine.muteLocalVideoStream(true);
    await _engine.stopPreview();
  }

  Future<void> _resumeCameraAfterBackground() async {
    if (BackgroundVideoService.isAndroid) {
      return;
    }
    if (!_isReady) return;
    await _engine.startPreview();
    await _engine.muteLocalVideoStream(false);
  }

  // --- INIZIALIZZAZIONE ---

  Future<void> _loadCameraNames() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final uid in kCamUids) {
        _cameraNames[uid] = prefs.getString('cam_name_$uid') ??
            'CAM ${kCamUids.indexOf(uid) + 1}';
      }
    });
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
            _createDataStream();
            if (isCamera) {
              BackgroundVideoService.start();
              _startKioskForPairedCamera();
            }
          },
          onLeaveChannel: (connection, stats) {
            if (mounted) setState(() => _isJoined = false);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            if (!kCamUids.contains(remoteUid)) return;
            setState(() {
              _activeCameras.add(remoteUid);
              if (_activeCameras.length == 1 &&
                  !_activeCameras.contains(_selectedViewUid)) {
                _selectedViewUid = remoteUid;
              }
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              _activeCameras.remove(remoteUid);
              _networkQuality.remove(remoteUid);
              if (_selectedViewUid == remoteUid && _activeCameras.isNotEmpty) {
                _selectedViewUid = _activeCameras.first;
              }
            });
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            if (state == ConnectionStateType.connectionStateReconnecting) {
              setState(() => _isReconnecting = true);
            } else if (state == ConnectionStateType.connectionStateConnected) {
              setState(() => _isReconnecting = false);
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
            if (isCamera && message == 'FLASH') _toggleLocalFlash();
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
        orientationMode: OrientationMode.orientationModeFixedPortrait,
        degradationPreference: DegradationPreference
            .maintainFramerate, // Preferisce fluidità alla risoluzione se la rete cala
      ));

      await _engine.enableVideo();
      // Abilita indicazione volume per vedere chi parla
      await _engine.enableAudioVolumeIndication(
          interval: 200, smooth: 3, reportVad: true);

      await _engine.setClientRole(
        role: isCamera
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );

      if (isCamera) {
        await _engine.startPreview();
      }

      await _engine.joinChannel(
        token: '',
        channelId: kChannelName,
        uid: myUid,
        options: ChannelMediaOptions(
          publishCameraTrack: isCamera,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: isCamera
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
        ),
      );

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
    });
    await _initAgora();
  }

  // --- LOGICA DI CONTROLLO ---

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (!_showControls) return;
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_ecoMode) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _toggleLocalFlash() async {
    if (!isCamera) return;
    try {
      bool newVal = !_isFlashOn;
      await _engine.setCameraTorchOn(newVal);
      if (!mounted) return;
      setState(() => _isFlashOn = newVal);
    } catch (e) {
      debugPrint("Flash Error: $e");
      _showMediaError('Impossibile aggiornare la torcia.');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _engine.switchCamera();
    } catch (error) {
      debugPrint('Switch camera error: $error');
      _showMediaError('Impossibile cambiare fotocamera.');
    }
  }

  Future<void> _createDataStream() async {
    _streamId = await _engine.createDataStream(
      const DataStreamConfig(syncWithAudio: false, ordered: true),
    );
  }

  Future<void> _sendRemoteFlash() async {
    if (_streamId == null) return;
    try {
      final data = Uint8List.fromList('FLASH'.codeUnits);
      await _engine.sendStreamMessage(
        streamId: _streamId!,
        data: data,
        length: data.length,
      );
      HapticFeedback.selectionClick();
    } catch (error) {
      debugPrint('Remote torch command failed: $error');
      _showMediaError('Impossibile inviare il comando torcia.');
    }
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
    try {
      if (isCamera) {
        await _engine.muteLocalVideoStream(enable);
      }
      if (!mounted) return;
      setState(() {
        _ecoMode = enable;
        _showControls = !enable;
      });
      if (!enable) _resetControlsTimer();
    } catch (error) {
      debugPrint('Eco mode error: $error');
      _showMediaError('Impossibile aggiornare la modalità risparmio.');
    }
  }

  Future<void> _toggleRemoteAudio() async {
    final enable = !_audioEnabled;
    try {
      await _engine.muteAllRemoteAudioStreams(!enable);
      if (!mounted) return;
      setState(() => _audioEnabled = enable);
    } catch (error) {
      debugPrint('Remote audio error: $error');
      _showMediaError('Impossibile aggiornare l’audio remoto.');
    }
  }

  void _showMediaError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Schermata sicurezza',
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: () {
            if (_ecoMode) return;
            setState(() {
              _showControls = !_showControls;
              if (_showControls) _resetControlsTimer();
            });
          },
          onDoubleTap: () => _toggleEcoMode(false),
          child: Stack(
          children: [
            // 1. VIDEO LAYER
            SizedBox.expand(child: _buildVideoArea()),

            // 2. OVERLAY RECONNECTING
            if (_isReconnecting)
              Container(
                color: Colors.black54,
                child: const Center(
                    child: Text("Riconnessione in corso...",
                        style: TextStyle(color: Colors.white))),
              ),

            // 3. UI CONTROLS
            if (!_ecoMode) ...[
              _buildTopBar(),
              _buildBottomControls(),
            ],

            // 4. ECO MODE
            if (_ecoMode) _buildEcoOverlay(),
          ],
          ),
        ),
      ),
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
      return AgoraVideoView(
          controller: VideoViewController(
              rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)));
    } else {
      // LOGICA VISORE
      if (_activeCameras.contains(_selectedViewUid)) {
        return AgoraVideoView(
          key: ValueKey(
              _selectedViewUid), // Importante per performance: ricrea view solo se cambia UID
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _selectedViewUid),
            connection: RtcConnection(channelId: _channelId),
          ),
        );
      } else {
        return _buildOfflineView();
      }
    }
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

  Widget _buildOfflineView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_wifi_off,
              color: Colors.white.withValues(alpha: 0.3), size: 60),
          const SizedBox(height: 20),
          Text(
            "Segnale assente dalla camera selezionata",
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (_activeCameras.isNotEmpty)
            const Text("Seleziona una camera attiva dalla lista in basso",
                style: TextStyle(color: Colors.blueAccent)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: _showControls ? 0 : -120,
      left: 0,
      right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _StatusDot(isConnected: _isJoined),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCamera
                          ? (_isJoined
                              ? "TRASMISSIONE ATTIVA"
                              : "TELECAMERA DISCONNESSA")
                          : (_isJoined
                              ? "MONITORAGGIO LIVE"
                              : "VISORE DISCONNESSO"),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    if (!isCamera && _activeCameras.contains(_selectedViewUid))
                      Text(
                        _cameraNames[_selectedViewUid] ?? "",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white70),
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showControls ? 30 : -200,
      left: 15,
      right: 15,
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
        child: isCamera ? _buildCameraButtons() : _buildViewerInterface(),
      ),
    );
  }

  // --- CONTROLLI VISORE MIGLIORATI ---
  Widget _buildViewerInterface() {
    const cameraUids = kCamUids;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. LISTA CAMERE ORIZZONTALE
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cameraUids.length,
            itemBuilder: (ctx, index) {
              int uid = cameraUids[index];
              bool isActive = _activeCameras.contains(uid);
              bool isSelected = _selectedViewUid == uid;

              // Calcolo Qualità Rete (0=N/A, 1-2=Good, 3-4=Poor, 5-6=Bad)
              int quality = _networkQuality[uid] ?? 0;
              Color qualityColor = (quality > 0 && quality <= 2)
                  ? Colors.green
                  : (quality <= 4 && quality > 0)
                      ? Colors.orange
                      : (isActive ? Colors.red : Colors.grey);

              return Semantics(
                button: true,
                selected: isSelected,
                label:
                    '${_cameraNames[uid] ?? 'Camera'}. ${isActive ? 'Connessa' : 'Disconnessa'}',
                hint: 'Tocca per selezionare, tieni premuto per rinominare',
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedViewUid = uid);
                    HapticFeedback.selectionClick();
                  },
                  onLongPress: () => _showRenameDialog(uid),
                  child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  width: 70,
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
                      // Icona Camera con Indicatore Rete
                      Stack(
                        children: [
                          Icon(Icons.videocam,
                              color: isActive ? Colors.white : Colors.white24,
                              size: 28),
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
                      const SizedBox(height: 5),
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
                    ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 20),

        // 2. PULSANTI AZIONE (Flash, Mic, Audio)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.highlight,
              isActive: _activeCameras.contains(_selectedViewUid),
              color: Colors.orangeAccent,
              onTap: _activeCameras.contains(_selectedViewUid)
                  ? _sendRemoteFlash
                  : () {},
            ),

            const Tooltip(
              message: 'Audio disabilitato dalla policy privacy',
              child: Icon(Icons.mic_off, color: Colors.white38, size: 32),
            ),

            _ActionButton(
              icon: _audioEnabled ? Icons.volume_up : Icons.volume_off,
              isActive: true, // Sempre cliccabile
              color: _audioEnabled ? Colors.white : Colors.grey,
              onTap: _toggleRemoteAudio,
            ),
          ],
        ),
      ],
    );
  }

  // --- CONTROLLI TELECAMERA ---
  Widget _buildCameraButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.flip_camera_ios,
          isActive: true,
          color: Colors.blueAccent,
          onTap: _switchCamera,
          label: "Gira",
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
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield, color: Colors.greenAccent, size: 80),
          const SizedBox(height: 20),
          Text("ECO SECURITY MODE",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text("Risparmio energetico attivo",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 40),
          Text("Doppio tocco per sbloccare",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
        ],
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
  final bool isConnected;
  const _StatusDot({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isConnected ? 'Connesso' : 'Disconnesso',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(seconds: 1),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isConnected ? Colors.greenAccent : Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red)
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
