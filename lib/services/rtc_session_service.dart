import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RtcSession {
  const RtcSession({
    required this.appId,
    required this.channelId,
    required this.expiresAt,
    required this.role,
    required this.token,
    required this.uid,
  });

  final String appId;
  final String channelId;
  final DateTime expiresAt;
  final String role;
  final String token;
  final int uid;

  factory RtcSession.fromMap(Map<Object?, Object?> data) {
    final appId = data['appId'];
    final channelId = data['channelId'];
    final expiresAt = data['expiresAt'];
    final role = data['role'];
    final token = data['token'];
    final uid = data['uid'];

    if (appId is! String ||
        channelId is! String ||
        expiresAt is! int ||
        role is! String ||
        token is! String ||
        uid is! int) {
      throw const FormatException('Invalid RTC session returned by the server.');
    }

    return RtcSession(
      appId: appId,
      channelId: channelId,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
      role: role,
      token: token,
      uid: uid,
    );
  }
}

class RtcSessionService {
  RtcSessionService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<RtcSession> createSession({
    required String homeId,
    required String deviceId,
    required bool isCamera,
  }) async {
    if (_auth.currentUser == null) {
      throw StateError('Authentication is required before requesting RTC access.');
    }

    final result = await _functions
        .httpsCallable('createRtcSession')
        .call<Map<String, Object?>>({
      'homeId': homeId,
      'deviceId': deviceId,
      'role': isCamera ? 'camera' : 'viewer',
    });

    return RtcSession.fromMap(
      Map<Object?, Object?>.from(result.data),
    );
  }
}
