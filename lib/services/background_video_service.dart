import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundVideoService {
  static const _serviceId = 101;

  static void initialize() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'camera_streaming',
        channelName: 'Trasmissione telecamera',
        channelDescription:
            'Mostra quando la telecamera trasmette video in background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start() async {
    if (!isAndroid) return;
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.camera],
      notificationTitle: 'Trasmissione video attiva',
      notificationText: 'La telecamera continua a trasmettere in background.',
      callback: _startCallback,
    );
  }

  static Future<void> stop() async {
    if (isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundVideoTaskHandler());
}

class _BackgroundVideoTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
