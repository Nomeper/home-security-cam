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

  /// Hides status/navigation chrome (clock, icons, nav bar) while ECO is on.
  Future<void> setEcoChrome(bool enabled) async {
    try {
      await _channel.invokeMethod('setEcoChrome', {'enabled': enabled});
    } on MissingPluginException {
      // Tests and platforms without the Android kiosk channel.
    } on PlatformException catch (error) {
      debugPrint('setEcoChrome failed: $error');
    }
  }

  /// Standby: lo schermo può spegnersi da solo. Live: tiene lo schermo acceso.
  /// Non cambia la luminosità: quella si abbassa solo con [blankDisplay].
  Future<void> setCameraPowerSave(
    bool enabled, {
    Duration screenTimeout = const Duration(seconds: 15),
  }) async {
    try {
      await _channel.invokeMethod('setCameraPowerSave', {
        'enabled': enabled,
        'timeoutMs': screenTimeout.inMilliseconds,
      });
    } on MissingPluginException {
      // Tests and platforms without the Android kiosk channel.
    } on PlatformException catch (error) {
      debugPrint('setCameraPowerSave failed: $error');
    }
  }

  /// A fine countdown: niente scritte, luminosità a 0; in kiosk spegne il pannello.
  Future<void> blankDisplay(bool enabled) async {
    try {
      await _channel.invokeMethod('blankDisplay', {'enabled': enabled});
    } on MissingPluginException {
      // Tests and platforms without the Android kiosk channel.
    } on PlatformException catch (error) {
      debugPrint('blankDisplay failed: $error');
    }
  }

  /// Flash frontale: schermo bianco a luminosità massima, e sveglia il pannello.
  Future<void> setScreenFlashlight(
    bool enabled, {
    bool restoreSystemBars = true,
  }) async {
    try {
      await _channel.invokeMethod('setScreenFlashlight', {
        'enabled': enabled,
        'restoreSystemBars': restoreSystemBars,
      });
    } on MissingPluginException {
      // Tests and platforms without the Android kiosk channel.
    } on PlatformException catch (error) {
      debugPrint('setScreenFlashlight failed: $error');
    }
  }

  /// Apre un URL https nel browser predefinito del sistema.
  Future<void> openUrl(String url) async {
    await _channel.invokeMethod('openUrl', {'url': url});
  }
}
