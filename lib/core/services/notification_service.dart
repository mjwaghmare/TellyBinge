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
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      final Duration offset = DateTime.now().timeZoneOffset;
      final timeZone = tz.TimeZone(
        offset,
        isDst: false,
        abbreviation: timeZoneName,
      );
      final location = tz.Location(
        timeZoneName,
        [0],
        [0],
        [timeZone],
      );
      tz.setLocalLocation(location);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false);

    const InitializationSettings initializationSettings = InitializationSettings(
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
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

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
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true);
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

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

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
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

    final rawDate = DateTime.tryParse(releaseDateStr);
    if (rawDate == null) return;

    // If string is YYYY-MM-DD format (no time specified), set to 9:00 AM local time
    DateTime releaseDate;
    if (releaseDateStr.length <= 10) {
      releaseDate = DateTime(rawDate.year, rawDate.month, rawDate.day, 9, 0);
    } else {
      releaseDate = rawDate;
    }

    final notify1HourBefore = prefs.getBool('notify_1_hour_before') ?? false;

    // 1. Core Notification on Release Day / Air Time
    if (releaseDate.isAfter(DateTime.now())) {
      await scheduleReleaseNotification(
        id: id * 10 + 1,
        title: '$title (Today)',
        body: body.replaceAll('airing soon', 'airing today'),
        scheduledDate: releaseDate,
      );
    }

    // 2. Optional Notification 1 Hour Before Air Time
    if (notify1HourBefore) {
      final oneHourBeforeDate = releaseDate.subtract(const Duration(hours: 1));
      if (oneHourBeforeDate.isAfter(DateTime.now())) {
        await scheduleReleaseNotification(
          id: id * 10 + 2,
          title: '$title (In 1 Hour)',
          body: body.replaceAll('airing soon', 'airing in 1 hour'),
          scheduledDate: oneHourBeforeDate,
        );
      }
    }
  }
}
