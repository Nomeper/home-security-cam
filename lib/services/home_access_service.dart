import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairingCode {
  const PairingCode({
    required this.code,
    required this.expiresAt,
    required this.target,
    this.deviceId,
  });

  final String code;
  final String? deviceId;
  final DateTime expiresAt;
  final String target;
}

class HomeCamera {
  const HomeCamera({required this.deviceId, required this.agoraUid});

  final String deviceId;
  final int agoraUid;
}

class HomeAccessService {
  HomeAccessService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  void _requireUser() {
    if (_auth.currentUser == null) {
      throw StateError('Authentication is required.');
    }
  }

  Future<String> createHome() async {
    _requireUser();
    final result =
        await _functions.httpsCallable('createHome').call<Map<String, Object?>>();
    final homeId = result.data['homeId'];
    if (homeId is! String) {
      throw const FormatException('Invalid home returned by the server.');
    }
    return homeId;
  }

  Future<PairingCode> createPairingCode({
    required String homeId,
    required String target,
  }) async {
    _requireUser();
    final result = await _functions
        .httpsCallable('createPairingCode')
        .call<Map<String, Object?>>({'homeId': homeId, 'target': target});
    final data = result.data;
    final code = data['code'];
    final deviceId = data['deviceId'];
    final expiresAt = data['expiresAt'];
    final returnedTarget = data['target'];
    if (code is! String ||
        expiresAt is! int ||
        returnedTarget is! String ||
        (deviceId != null && deviceId is! String)) {
      throw const FormatException('Invalid pairing code returned by the server.');
    }
    return PairingCode(
      code: code,
      deviceId: deviceId as String?,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
      target: returnedTarget,
    );
  }

  Future<String?> redeemPairingCode({
    required String homeId,
    required String code,
  }) async {
    _requireUser();
    final result = await _functions
        .httpsCallable('redeemPairingCode')
        .call<Map<String, Object?>>({'homeId': homeId, 'code': code});
    final deviceId = result.data['deviceId'];
    if (deviceId != null && deviceId is! String) {
      throw const FormatException('Invalid device returned by the server.');
    }
    return deviceId as String?;
  }

  Future<List<HomeCamera>> listCameras({required String homeId}) async {
    _requireUser();
    final result = await _functions
        .httpsCallable('listHomeCameras')
        .call<Map<String, Object?>>({'homeId': homeId});
    final cameras = result.data['cameras'];
    if (cameras is! List) {
      throw const FormatException('Invalid cameras returned by the server.');
    }
    return cameras.map((camera) {
      if (camera is! Map) {
        throw const FormatException('Invalid camera returned by the server.');
      }
      final deviceId = camera['deviceId'];
      final agoraUid = camera['agoraUid'];
      if (deviceId is! String || agoraUid is! int) {
        throw const FormatException('Invalid camera returned by the server.');
      }
      return HomeCamera(deviceId: deviceId, agoraUid: agoraUid);
    }).toList(growable: false);
  }
}
