import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions requested as soon as the APK launches, before the
/// user picks a role or starts camera / talk / listen.
class StartupPermissions {
  static const runtime = <Permission>[
    Permission.camera,
    Permission.microphone,
    Permission.notification,
  ];

  static Future<void> requestAll() async {
    await runtime.request();
    await _requestForegroundNotification();
  }

  static Future<void> _requestForegroundNotification() async {
    try {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // Plugin may be unavailable in tests; splash must still continue.
    }
  }
}
