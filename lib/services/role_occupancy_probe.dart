import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import '../channel_encryption.dart';
import '../utils.dart';

/// Entra nel canale senza pubblicare, per vedere CAM e visore già connessi.
class RoleOccupancyProbe {
  RoleOccupancyProbe({
    required this.onOccupiedRoles,
    this.onReady,
  });

  final void Function(Set<DeviceRole> occupied) onOccupiedRoles;
  final VoidCallback? onReady;

  RtcEngine? _engine;
  bool _started = false;
  int _generation = 0;
  final Set<int> _presentUids = {};

  Future<void> start(String appId, {required String channelKey}) async {
    if (_started) return;
    _started = true;
    final generation = ++_generation;
    try {
      final engine = createAgoraRtcEngine();
      if (!_isCurrent(generation)) {
        await _releaseEngine(engine);
        return;
      }
      _engine = engine;
      await engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      if (!_isCurrent(generation)) {
        await _releaseEngine(engine);
        return;
      }
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!_isCurrent(generation)) return;
            // Utenti già nel canale possono arrivare dopo il join.
            for (final delayMs in [0, 400, 900, 1600]) {
              Future<void>.delayed(Duration(milliseconds: delayMs), () {
                if (!_isCurrent(generation)) return;
                _emit();
                if (delayMs == 1600) {
                  onReady?.call();
                }
              });
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!_isCurrent(generation)) return;
            _presentUids.add(remoteUid);
            _emit();
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!_isCurrent(generation)) return;
            _presentUids.remove(remoteUid);
            _emit();
          },
        ),
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableLocalVideo(false);
      await engine.enableLocalAudio(false);
      await enableChannelEncryption(engine, channelKey);
      if (!_isCurrent(generation)) {
        await _releaseEngine(engine);
        return;
      }
      await engine.joinChannel(
        token: '',
        channelId: kChannelName,
        uid: randomRoleProbeUid(),
        options: const ChannelMediaOptions(
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          autoSubscribeAudio: false,
          autoSubscribeVideo: false,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (error) {
      debugPrint('Role occupancy probe failed: $error');
      await stop();
      onReady?.call();
    }
  }

  bool _isCurrent(int generation) => generation == _generation && _started;

  void _emit() {
    onOccupiedRoles(occupiedRolesFromUids(_presentUids));
  }

  Future<void> stop() async {
    final engine = _engine;
    _engine = null;
    _started = false;
    _generation++;
    _presentUids.clear();
    await _releaseEngine(engine);
  }

  Future<void> _releaseEngine(RtcEngine? engine) async {
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (error) {
      debugPrint('Role occupancy probe leave failed: $error');
    }
    try {
      await engine.release();
    } catch (error) {
      debugPrint('Role occupancy probe release failed: $error');
    }
  }
}
