import 'utils.dart';

enum AppLaunchRoute { appId, roleSelection, security }

class AppLaunchDecision {
  static AppLaunchRoute decide({
    required bool hasAppId,
    required bool hasChannelKey,
    required bool isDeviceOwner,
  }) {
    if (!hasAppId || !hasChannelKey) return AppLaunchRoute.appId;
    if (isDeviceOwner) return AppLaunchRoute.security;
    return AppLaunchRoute.roleSelection;
  }

  static DeviceRole roleForDeviceOwner() => DeviceRole.camera1;
}
