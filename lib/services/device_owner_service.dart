import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceOwnerStatus {
  const DeviceOwnerStatus({
    required this.isDeviceOwner,
    required this.isLockTaskActive,
  });

  final bool isDeviceOwner;
  final bool isLockTaskActive;

  factory DeviceOwnerStatus.fromMap(Map<Object?, Object?> data) {
    final isDeviceOwner = data['isDeviceOwner'];
    final isLockTaskActive = data['isLockTaskActive'];
    if (isDeviceOwner is! bool || isLockTaskActive is! bool) {
      throw const FormatException('Invalid Device Owner status from Android.');
    }
    return DeviceOwnerStatus(
      isDeviceOwner: isDeviceOwner,
      isLockTaskActive: isLockTaskActive,
    );
  }
}

class DeviceOwnerService {
  static const _channel =
      MethodChannel('com.bebobbx.home_security_cam/device_owner');

  Future<DeviceOwnerStatus> getStatus() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
    if (result == null) {
      throw const FormatException('Missing Device Owner status from Android.');
    }
    return DeviceOwnerStatus.fromMap(result);
  }

  Future<bool> isManagedCamera() async {
    try {
      return (await getStatus()).isDeviceOwner;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> canStartLockTask() async {
    if (kDebugMode) return false;
    return isManagedCamera();
  }

  Future<void> startLockTask() => _channel.invokeMethod('startLockTask');

  Future<void> stopLockTask() => _channel.invokeMethod('stopLockTask');
}
