import 'package:fl_clash/common/common.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

/// System notifications for run status.
class AppNotification {
  AppNotification._();

  static bool _initialized = false;

  static final _android = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      if (system.isAndroid) {
        const settings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );
        await _android.initialize(settings: settings);
        await _android
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (system.isDesktop) {
        await localNotifier.setup(appName: appName);
      }
    } catch (_) {
      // A missing permission or platform support must not stop the app.
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      return;
    }
    try {
      if (system.isAndroid) {
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'connection_status',
            '连接状态',
            channelDescription: '连接状态通知',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        );
        await _android.show(
          id: 1,
          title: title,
          body: body,
          notificationDetails: details,
        );
      } else if (system.isDesktop) {
        final notification = LocalNotification(
          identifier: 'connection_status',
          title: title,
          body: body,
        );
        await notification.show();
      }
    } catch (_) {
      // Notifications are best effort.
    }
  }
}
