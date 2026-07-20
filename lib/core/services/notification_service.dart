import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false);

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> sendTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('test_channel', 'Test Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: 999,
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> scheduleReleaseNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Don't schedule in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('release_channel', 'Release Notifications',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id * 10 + 1);
    await _notificationsPlugin.cancel(id: id * 10 + 2);
  }

  Future<void> scheduleBasedOnSettings({
    required int id,
    required String title,
    required String body,
    required String? releaseDateStr,
  }) async {
    if (releaseDateStr == null || releaseDateStr.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    if (!notificationsEnabled) return;

    final releaseDate = DateTime.tryParse(releaseDateStr);
    if (releaseDate == null) return;

    final notify1HourBefore = prefs.getBool('notify_1_hour_before') ?? false;
    final notify1DayBefore = prefs.getBool('notify_1_day_before') ?? true;

    if (notify1HourBefore) {
      final scheduledDate = releaseDate.subtract(const Duration(hours: 1));
      if (scheduledDate.isAfter(DateTime.now())) {
        await scheduleReleaseNotification(
          id: id * 10 + 1,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        );
      }
    }

    if (notify1DayBefore) {
      final scheduledDate = releaseDate.subtract(const Duration(hours: 24));
      if (scheduledDate.isAfter(DateTime.now())) {
        await scheduleReleaseNotification(
          id: id * 10 + 2,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
        );
      }
    }
  }
}
