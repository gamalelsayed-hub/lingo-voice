import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app alive with a notification while it listens, so the learner
/// can leave the app or lock the phone. Android requires the notification
/// for any app that uses the microphone in the background.
class BackgroundService {
  BackgroundService._();

  static const summaryButton = 'summary';
  static const stopButton = 'stop';

  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'listening',
        channelName: 'الاستماع',
        channelDescription: 'يظهر وقت ما التطبيق يسمعك',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: 'Lingo Voice يسمعك',
      notificationText: 'تكلم براحتك، ولما تسكت أقول لك كلامك بالإنجليزي.',
      notificationButtons: const [
        NotificationButton(id: summaryButton, text: 'الملخص الآن'),
        NotificationButton(id: stopButton, text: 'إيقاف'),
      ],
      callback: startCallback,
    );
  }

  static Future<void> update(String text) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Lingo Voice يسمعك',
      notificationText: text,
    );
  }

  static Future<void> stop() => FlutterForegroundTask.stopService();

  /// Called with [summaryButton] or [stopButton] when the learner taps a
  /// notification button.
  static void onButton(void Function(String id) handler) {
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is String) handler(data);
    });
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ButtonForwarder());
}

/// Runs in the service's isolate; forwards notification taps to the app,
/// where the listening session lives.
class _ButtonForwarder extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) =>
      FlutterForegroundTask.sendDataToMain(id);

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
