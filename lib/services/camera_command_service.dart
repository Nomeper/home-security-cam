import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CameraCommand {
  const CameraCommand({
    required this.id,
    required this.desiredState,
  });

  final String id;
  final bool desiredState;
}

class CameraCommandService {
  CameraCommandService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<void> sendTorch({
    required String homeId,
    required String deviceId,
    required bool desiredState,
  }) async {
    await _functions.httpsCallable('sendCameraCommand').call({
      'homeId': homeId,
      'deviceId': deviceId,
      'type': 'torch',
      'desiredState': desiredState,
    });
  }

  Stream<CameraCommand> watchPendingTorchCommands({
    required String homeId,
    required String deviceId,
  }) {
    return _firestore
        .collection('homes')
        .doc(homeId)
        .collection('devices')
        .doc(deviceId)
        .collection('commands')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .expand((snapshot) => snapshot.docs)
        .map<CameraCommand?>((document) {
      final data = document.data();
      final expiresAt = data['expiresAt'];
      if (data['type'] != 'torch' ||
          data['desiredState'] is! bool ||
          expiresAt is! Timestamp ||
          expiresAt.toDate().isBefore(DateTime.now())) {
        return null;
      }
      return CameraCommand(
        id: document.id,
        desiredState: data['desiredState'] as bool,
      );
    }).where((command) => command != null).map((command) => command!);
  }

  Future<void> acknowledge({
    required String homeId,
    required String deviceId,
    required String commandId,
    required bool succeeded,
  }) async {
    await _functions.httpsCallable('acknowledgeCameraCommand').call({
      'homeId': homeId,
      'deviceId': deviceId,
      'commandId': commandId,
      'succeeded': succeeded,
    });
  }
}
