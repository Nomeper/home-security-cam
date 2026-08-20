import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundVideoService {
  static const _serviceId = 101;

  static final _standbyOptions = ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.nothing(),
    allowWakeLock: false,
    allowWifiLock: false,
  );

  static void initialize() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'camera_streaming',
        channelName: 'Trasmissione telecamera',
        channelDescription:
            'Mostra quando la telecamera resta in ascolto o trasmette.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: _standbyOptions,
    );
  }

  static Future<void> start({bool live = false}) async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) {
      await setLive(live);
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.camera],
      notificationTitle: live
          ? 'Trasmissione video attiva'
          : 'Telecamera in attesa',
      notificationText: live
          ? 'La telecamera continua a trasmettere in background.'
          : 'Sensore spento. Si accende quando il visore la seleziona.',
      callback: _startCallback,
    );
  }

  static Future<void> setLive(bool live) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle:
          live ? 'Trasmissione video attiva' : 'Telecamera in attesa',
      notificationText: live
          ? 'La telecamera continua a trasmettere in background.'
          : 'Sensore spento. Si accende quando il visore la seleziona.',
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
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
