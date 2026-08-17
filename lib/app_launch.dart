import 'utils.dart';

enum AppLaunchRoute { appId, roleSelection, security }

class AppLaunchDecision {
  static AppLaunchRoute decide({
    required bool hasAppId,
    required bool isDeviceOwner,
    required String? role,
  }) {
    if (!hasAppId) return AppLaunchRoute.appId;
    if (isDeviceOwner) return AppLaunchRoute.security;
    if (role == null || role.isEmpty) return AppLaunchRoute.roleSelection;
    return AppLaunchRoute.security;
  }

  static DeviceRole roleForDeviceOwner() => DeviceRole.camera1;
}
