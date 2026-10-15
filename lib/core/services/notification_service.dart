import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../constants/app_storage_keys.dart';
import '../utils/executable_stat/executable_stat.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Represents a notification that has actually been pushed or received on device.
class ReceivedNotificationItem {
  final String id;
  final String title;
  final String body;
  final String? payload;
  final String timestamp;

  const ReceivedNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'payload': payload,
    'timestamp': timestamp,
  };

  factory ReceivedNotificationItem.fromJson(Map<String, dynamic> json) =>
      ReceivedNotificationItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        payload: json['payload'] as String?,
        timestamp: json['timestamp'] as String? ?? '',
      );
}

/// Internal model for keeping track of alerts scheduled with the platform.
class _ScheduledRegistryItem {
  final String id;
  final String title;
  final String body;
  final String? payload;
  final DateTime scheduledDate;

  const _ScheduledRegistryItem({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    required this.scheduledDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'payload': payload,
    'scheduledDate': scheduledDate.toIso8601String(),
  };

  factory _ScheduledRegistryItem.fromJson(Map<String, dynamic> json) =>
      _ScheduledRegistryItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        payload: json['payload'] as String?,
        scheduledDate:
            DateTime.tryParse(json['scheduledDate'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Which watchlist a notification belongs to.
///
/// TMDB numbers TV shows and movies in separate namespaces that overlap — id
/// 1399 is a real show *and* a real movie. Without the kind baked into the
/// notification id, a user holding both would have one silently overwrite the
/// other, and cancelling either would cancel both.
enum NotificationMedia { tv, movie }

/// One title a watchlist wants notifications for. The service decides how many
/// alerts this expands into and whether it survives the platform cap.
class PendingNotification {
  final NotificationMedia media;
  final int mediaId;
  final String title;
  final String body;

  /// Raw TMDB date string; resolved once during reconcile.
  final String releaseDateStr;

  const PendingNotification({
    required this.media,
    required this.mediaId,
    required this.title,
    required this.body,
    required this.releaseDateStr,
  });
}

/// A single resolved alert, ready to hand to the platform.
class _ScheduledAlert {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  /// Deep link opened when the alert is tapped.
  final String payload;

  const _ScheduledAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });
}

/// A pending notification item formatted for presentation in UI views.
class ScheduledNotificationDisplayItem {
  final int id;
  final String title;
  final String body;
  final String? payload;
  final NotificationMedia? media;
  final int? mediaId;
  final DateTime? scheduledDate;

  const ScheduledNotificationDisplayItem({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    this.media,
    this.mediaId,
    this.scheduledDate,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Generates a funny, sarcastic, and varied notification title & body
  /// for a TV show episode based on the show's ID.
  static (String title, String body) generateTvNotificationContent({
    required int showId,
    required String showName,
    required String episodeCode,
  }) {
    final epText = episodeCode.isNotEmpty
        ? 'Episode $episodeCode'
        : 'New episode';
    final titles = [
      '🍿 $showName',
      '⏰ $showName',
      '📺 $showName',
      '🍿 $showName',
      '📺 $showName',
    ];
    final index = showId.abs() % titles.length;
    return (titles[index], '$epText airs {time}.');
  }

  /// Generates a funny, sarcastic, and varied notification title & body
  /// for a Movie release based on the movie's ID.
  static (String title, String body) generateMovieNotificationContent({
    required int movieId,
    required String movieTitle,
  }) {
    final titles = [
      '🎬 $movieTitle',
      '🍿 $movieTitle',
      '🎬 $movieTitle',
      '🍿 $movieTitle',
      '🌟 $movieTitle',
    ];
    final index = movieId.abs() % titles.length;
    return (titles[index], '$movieTitle premieres {time}.');
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Each title reserves this many notification ids: two per media kind, one
  /// for the day-before alert and one for the optional hour-before alert.
  static const int _slotsPerTitle = 4;

  static const int _slotDayBefore = 0;
  static const int _slotHourBefore = 1;

  /// Reserved id well above anything [_notificationId] can produce — the
  /// largest TMDB id today is around 1.5M, so ×4 stays under 7M.
  static const int _testNotificationId = 1 << 30;
  static const int _reinstallNotificationId = (1 << 30) - 2;
  static const int _reinstallNotificationId24h = (1 << 30) - 3;
  static const Duration _profileExpirationDuration = Duration(days: 6);

  /// Android status-bar icon. Must live in res/drawable (the plugin looks names
  /// up with defType "drawable", so res/mipmap entries are invisible to it), and
  /// must be alpha-only: since API 21 the system discards colour in this slot
  /// and tints the alpha channel, so an opaque bitmap renders as a solid block.
  static const String _androidStatusBarIcon =
      AppConstants.notificationAndroidStatusBarIcon;

  /// Full-colour logo shown as the notification's large icon. Also a drawable,
  /// because [DrawableResourceAndroidBitmap] decodes it with BitmapFactory.
  static const String _androidLargeIcon =
      AppConstants.notificationAndroidLargeIcon;

  static const String _prefHasUnread = AppStorageKeys.hasUnreadNotifications;
  static const String _prefReinstallReminderBuildTs =
      AppStorageKeys.reinstallReminderBuildTs;
  static const String _prefReinstallReminderScheduled =
      AppStorageKeys.reinstallReminderScheduled;
  static const String _prefAppInstallTimestamp =
      AppStorageKeys.appInstallTimestamp;
  static const String _prefLastActiveTimezone =
      AppStorageKeys.lastActiveTimezone;
  static const String _prefScheduledRegistry =
      AppStorageKeys.scheduledNotificationsRegistry;
  static const String _prefReceivedHistory =
      AppStorageKeys.receivedNotificationsHistory;
  static const String _prefNotify1DayBefore =
      AppStorageKeys.notify1DayBefore;
  static const String _prefNotificationsEnabled =
      AppStorageKeys.notificationsEnabled;

  int _notificationId(NotificationMedia media, int mediaId, int slot) =>
      mediaId * _slotsPerTitle + (media == NotificationMedia.tv ? 0 : 2) + slot;

  /// Matches the scheme the home-screen widget already uses, so notification
  /// taps route through the same handler.
  String _deepLinkFor(NotificationMedia media, int mediaId) =>
      media == NotificationMedia.tv
      ? 'tvtimeapp://show/$mediaId'
      : 'tvtimeapp://movie/$mediaId';

  /// Reactive notifier for whether unread notifications exist.
  final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(false);

  /// Single service-level operation queue to serialize all registry and history mutations.
  Future<void> _operationQueue = Future<void>.value();

  /// Override flag to simulate release mode in unit tests.
  @visibleForTesting
  static bool? debugReleaseModeOverride;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Initializes unread status from SharedPreferences.
  Future<void> _initUnreadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    hasUnreadNotifier.value =
        prefs.getBool(_prefHasUnread) ?? false;
  }

  /// Sets unread notification state and updates listeners & SharedPreferences.
  Future<void> _setHasUnread(bool value) async {
    hasUnreadNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHasUnread, value);
  }

  /// Marks all notifications as read.
  Future<void> markNotificationsAsRead() async {
    await _setHasUnread(false);
  }

  /// Cancels any scheduled iOS free developer provisioning profile reminders directly without queueing.
  Future<void> _cancelReinstallRemindersDirect() async {
    await _cancelNotificationByIdDirect(_reinstallNotificationId);
    await _cancelNotificationByIdDirect(_reinstallNotificationId24h);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReinstallReminderScheduled, false);
  }

  /// Cancels any scheduled iOS free developer provisioning profile reminders.
  Future<void> cancelReinstallReminders() =>
      _synchronized(() => _cancelReinstallRemindersDirect());

  /// Schedules reinstall reminder notifications ONLY on iOS Release builds
  /// for free-tier personal developer provisioning expiration, exclusively for admins.
  /// Schedules Day 5 (48h left) and Day 6 (24h left) notifications.
  Future<void> scheduleReinstallReminderIfNeeded({bool isAdmin = false}) =>
      _synchronized(() async {
        if (defaultTargetPlatform != TargetPlatform.iOS || !isAdmin) {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            await _cancelReinstallRemindersDirect();
          }
          return;
        }

        final isRelease = debugReleaseModeOverride ?? kReleaseMode;
        if (!isRelease) {
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final installTimestamp = await getAppInstallTimestamp();
        final lastScheduledBuild =
            prefs.getInt(_prefReinstallReminderBuildTs) ?? 0;

        // Reset scheduled flag if a new build timestamp is detected
        if (installTimestamp > lastScheduledBuild) {
          await prefs.setBool(_prefReinstallReminderScheduled, false);
          await prefs.setInt(_prefReinstallReminderBuildTs, installTimestamp);
        }

        final alreadyScheduled =
            prefs.getBool(_prefReinstallReminderScheduled) ?? false;
        if (alreadyScheduled) {
          return;
        }

        final installDate =
            DateTime.fromMillisecondsSinceEpoch(installTimestamp);
        final expirationDate = installDate.add(_profileExpirationDuration);
        final now = DateTime.now();

        // 48h left (2 days before expiration) and 24h left (1 day before expiration)
        final reminderDate48h =
            expirationDate.subtract(const Duration(days: 2));
        final reminderDate24h =
            expirationDate.subtract(const Duration(days: 1));

        bool allScheduled = true;
        try {
          if (reminderDate48h.isAfter(now)) {
            final success = await _scheduleOne(
              id: _reinstallNotificationId,
              title: "⏳ 2 Days Left on Free Profile",
              body:
                  "Your 7-day personal developer profile expires in 48 hours. Rebuild soon with Xcode! 💻",
              scheduledDate: reminderDate48h,
            );
            if (!success) allScheduled = false;
          } else if (reminderDate48h.isBefore(now) &&
              reminderDate24h.isAfter(now)) {
            await _saveReceivedNotificationDirect(
              id: _reinstallNotificationId.toString(),
              title: "⏳ 2 Days Left on Free Profile",
              body:
                  "Your 7-day personal developer profile expires in 48 hours. Rebuild soon with Xcode! 💻",
            );
          }

          if (reminderDate24h.isAfter(now)) {
            final success = await _scheduleOne(
              id: _reinstallNotificationId24h,
              title: "🚨 Profile Expires Tomorrow!",
              body:
                  "Free developer profile expires in 24 hours. Rebuild with Xcode today to keep the app working! 💻",
              scheduledDate: reminderDate24h,
            );
            if (!success) allScheduled = false;
          } else {
            if (expirationDate.isAfter(now)) {
              const title = "🚨 Profile Expires Very Soon!";
              const body =
                  "Free developer profile expires in less than 24 hours! Connect to Xcode and rebuild now. 💻";
              final success = await _scheduleOne(
                id: _reinstallNotificationId24h,
                title: title,
                body: body,
                scheduledDate: now.add(const Duration(minutes: 1)),
              );
              if (!success) allScheduled = false;
              await _saveReceivedNotificationDirect(
                id: _reinstallNotificationId24h.toString(),
                title: title,
                body: body,
              );
            }
          }

          if (allScheduled) {
            await prefs.setBool(_prefReinstallReminderScheduled, true);
          }
        } catch (e) {
          debugPrint('Failed to schedule reinstall reminders: $e');
        }
      });

  /// Returns the actual build/deployment timestamp of the app executable.
  /// Falls back to the persisted app install timestamp if file stat is unavailable.
  Future<int> getAppInstallTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    int? installTimestamp = prefs.getInt(_prefAppInstallTimestamp);

    final buildTime = getExecutableModifiedTimestamp();
    if (buildTime != null && buildTime > 0) {
      if (installTimestamp == null || buildTime > installTimestamp) {
        installTimestamp = buildTime;
        await prefs.setInt(_prefAppInstallTimestamp, installTimestamp);
      }
    }

    if (installTimestamp == null) {
      installTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_prefAppInstallTimestamp, installTimestamp);
    }

    return installTimestamp;
  }

  /// Returns the estimated free Apple Developer profile expiration date
  /// (6 days from app build/installation).
  Future<DateTime> getProfileExpirationDate() async {
    final timestamp = await getAppInstallTimestamp();
    final installDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return installDate.add(_profileExpirationDuration);
  }

  /// Resets the app install timestamp to now (used when app is rebuilt)
  /// and updates scheduled notifications accordingly.
  Future<DateTime> resetAppInstallTimestamp({bool isAdmin = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_prefAppInstallTimestamp, nowMs);
    await prefs.setBool(_prefReinstallReminderScheduled, false);

    await cancelNotificationById(_reinstallNotificationId);
    await cancelNotificationById(_reinstallNotificationId24h);
    await scheduleReinstallReminderIfNeeded(isAdmin: isAdmin);

    return DateTime.fromMillisecondsSinceEpoch(
      nowMs,
    ).add(_profileExpirationDuration);
  }

  Future<void> initialize() async {
    await _initUnreadStatus();
    await promoteFiredNotifications();
    await getAppInstallTimestamp();
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      final prefs = await SharedPreferences.getInstance();
      final lastTz = prefs.getString(_prefLastActiveTimezone);
      if (lastTz != null && lastTz != timeZoneName) {
        _lastScheduledSignature = null;
      }
      await prefs.setString(_prefLastActiveTimezone, timeZoneName);
    } catch (_) {
      // Fallback: preserve existing initialized location if platform timezone lookup fails
    }

    // Icon names resolve against res/drawable, not res/mipmap, so the launcher
    // icon can't be referenced here. See _androidStatusBarIcon.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(_androidStatusBarIcon);

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        promoteFiredNotifications();
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );

    await scheduleReinstallReminderIfNeeded(isAdmin: false);
  }

  /// Invoked with a `tvtimeapp://…` deep link when the user taps a scheduled
  /// notification.
  ///
  /// Assigned by the app rather than passed in: [initialize] runs from `main()`
  /// before a navigator exists, so there is nothing to route to yet.
  void Function(String payload)? onNotificationTap;

  /// Deep link for a notification that was tapped while the app was terminated.
  ///
  /// A cold launch has no live callback to fire, so the launch details have to
  /// be read once the app is up and routed manually.
  Future<String?> takeLaunchPayload() async {
    final details = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
  }

  /// Returns whether notifications are permitted afterwards, so callers can
  /// tell the difference between "user turned it on" and "the OS said no".
  Future<bool> requestPermissions() async {
    final iosGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final androidGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Exactly one implementation resolves per platform; the other is null.
    return iosGranted ?? androidGranted ?? false;
  }

  /// Current OS-level permission, independent of the in-app preference.
  ///
  /// The two drift apart easily: the user can revoke notifications in system
  /// settings long after enabling them here, and nothing in the app would
  /// otherwise notice.
  Future<bool> hasSystemPermission() async {
    final ios = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final options = await ios.checkPermissions();
      return options?.isEnabled ?? false;
    }

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    return false;
  }

  Future<void> sendTestNotification() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.deleteNotificationChannel(
      channelId: AppConstants.notificationTestChannelId,
    );

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          AppConstants.notificationTestChannelId,
          AppConstants.notificationTestChannelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: _androidStatusBarIcon,
          largeIcon: DrawableResourceAndroidBitmap(_androidLargeIcon),
        );
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await _notificationsPlugin.cancel(id: _testNotificationId);

    const title = '🔔 Test Notification';
    const body =
        'Notifications are enabled and active! You will receive show & movie release alerts. 🍿';

    await _notificationsPlugin.show(
      id: _testNotificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );

    await saveReceivedNotification(
      id: _testNotificationId.toString(),
      title: title,
      body: body,
    );
  }

  Future<bool> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final now = DateTime.now();
    // Don't schedule in the past
    if (scheduledDate.isBefore(now)) {
      return false;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          AppConstants.notificationReleaseChannelId,
          AppConstants.notificationReleaseChannelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: _androidStatusBarIcon,
          largeIcon: DrawableResourceAndroidBitmap(_androidLargeIcon),
        );
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (_) {
      try {
        // Fallback for Android 12+ (API 31+) if exact alarm permission is revoked by system/user
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: payload,
        );
        return true;
      } catch (e) {
        debugPrint('Failed to schedule notification $id: $e');
        return false;
      }
    }
  }

  /// Track canceled notification IDs for durable suppression across reconciles.
  final Set<int> _canceledNotificationIds = {};

  /// Drops one title's alerts immediately, without waiting for its watchlist
  /// stream to round-trip and trigger a reconcile.
  Future<void> cancelNotification(NotificationMedia media, int id) =>
      _synchronized(() async {
        final dayBeforeId = _notificationId(media, id, _slotDayBefore);
        final hourBeforeId = _notificationId(media, id, _slotHourBefore);

        _canceledNotificationIds.add(dayBeforeId);
        _canceledNotificationIds.add(hourBeforeId);

        if (_desired.containsKey(media)) {
          _desired[media]!.removeWhere((p) => p.mediaId == id);
        }

        await _notificationsPlugin.cancel(id: dayBeforeId);
        await _notificationsPlugin.cancel(id: hourBeforeId);
        await _removeFromScheduledRegistryDirect([
          dayBeforeId.toString(),
          hourBeforeId.toString(),
        ]);
        _lastScheduledSignature = null;
      });

  static const int _maxReceivedHistory = 20;

  Future<void> _removeFromScheduledRegistryDirect(
    List<String> idsToRemove,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList =
          prefs.getStringList(_prefScheduledRegistry) ?? [];
      if (rawList.isEmpty) return;

      final idSet = idsToRemove.toSet();
      final updatedList = rawList.where((jsonStr) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          return !idSet.contains(map['id']?.toString());
        } catch (_) {
          return true;
        }
      }).toList();

      await prefs.setStringList(
        _prefScheduledRegistry,
        updatedList,
      );
    } catch (_) {}
  }

  /// Scans the scheduled notifications registry and moves any alerts whose
  /// scheduled fire time has passed (<= now) into the received notifications history.
  Future<void> promoteFiredNotifications() => _synchronized(() async {
    await _promoteFiredNotificationsDirect();
  });

  Future<void> _promoteFiredNotificationsDirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList =
          prefs.getStringList(_prefScheduledRegistry) ?? [];
      if (rawList.isEmpty) return;

      final now = DateTime.now();
      final remaining = <String>[];
      bool hasPromoted = false;

      for (final jsonStr in rawList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final item = _ScheduledRegistryItem.fromJson(map);
          if (!item.scheduledDate.isAfter(now)) {
            final occurrenceId =
                '${item.id}_${item.scheduledDate.millisecondsSinceEpoch}';
            await _saveReceivedNotificationDirect(
              id: occurrenceId,
              title: item.title,
              body: item.body,
              payload: item.payload,
              timestamp: item.scheduledDate.toIso8601String(),
            );
            hasPromoted = true;
          } else {
            remaining.add(jsonStr);
          }
        } catch (_) {
          // Drop corrupted item
        }
      }

      if (hasPromoted || remaining.length != rawList.length) {
        await prefs.setStringList(
          _prefScheduledRegistry,
          remaining,
        );
      }
    } catch (e) {
      debugPrint('Failed to promote fired scheduled notifications: $e');
    }
  }

  /// Saves a notification that was received/pushed to local history.
  /// Enforces strict FIFO rule with deduplication: max 20 items (oldest evicted).
  Future<void> saveReceivedNotification({
    required String title,
    required String body,
    String? payload,
    String? id,
    String? timestamp,
  }) => _synchronized(() async {
    await _saveReceivedNotificationDirect(
      title: title,
      body: body,
      payload: payload,
      id: id,
      timestamp: timestamp,
    );
  });

  Future<void> _saveReceivedNotificationDirect({
    required String title,
    required String body,
    String? payload,
    String? id,
    String? timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefReceivedHistory) ?? [];

    final itemId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Filter out duplicate ID if it already exists in history
    final filteredList = rawList.where((jsonStr) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return map['id']?.toString() != itemId;
      } catch (_) {
        return true;
      }
    }).toList();

    final newItem = ReceivedNotificationItem(
      id: itemId,
      title: title,
      body: body,
      payload: payload,
      timestamp: timestamp ?? DateTime.now().toIso8601String(),
    );

    final updatedList = <String>[jsonEncode(newItem.toJson()), ...filteredList];

    // Sort by timestamp descending so the most recently aired appear at the top
    final parsedItems = <ReceivedNotificationItem>[];
    for (final jsonStr in updatedList) {
      try {
        parsedItems.add(
          ReceivedNotificationItem.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    parsedItems.sort((a, b) {
      final dateA =
          DateTime.tryParse(a.timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          DateTime.tryParse(b.timestamp) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    final sortedJsonList = parsedItems
        .take(_maxReceivedHistory)
        .map((e) => jsonEncode(e.toJson()))
        .toList();

    await prefs.setStringList(_prefReceivedHistory, sortedJsonList);
    await _setHasUnread(true);
  }

  /// Retrieves received notifications history (most recent first, max 20).
  /// Automatically runs promotion first so any newly fired alerts are included.
  Future<List<ReceivedNotificationItem>> getReceivedNotifications() =>
      _synchronized(() async {
        await _promoteFiredNotificationsDirect();
        final prefs = await SharedPreferences.getInstance();
        final rawList =
            prefs.getStringList(_prefReceivedHistory) ?? [];

        final items = <ReceivedNotificationItem>[];
        for (final jsonStr in rawList) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            items.add(ReceivedNotificationItem.fromJson(map));
          } catch (_) {}
        }
        return items;
      });

  /// Removes a single received notification by ID from history.
  Future<void> removeReceivedNotification(String id) => _synchronized(() async {
    await _removeReceivedNotificationDirect(id);
  });

  Future<void> _removeReceivedNotificationDirect(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefReceivedHistory) ?? [];
    final updatedList = <String>[];

    for (final jsonStr in rawList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map['id']?.toString() != id &&
            !map['id']!.toString().startsWith('${id}_')) {
          updatedList.add(jsonStr);
        }
      } catch (_) {}
    }

    await prefs.setStringList(_prefReceivedHistory, updatedList);
    if (updatedList.isEmpty) {
      await _setHasUnread(false);
    }
  }

  Future<void> _cancelNotificationByIdDirect(int id) async {
    _canceledNotificationIds.add(id);

    for (final list in _desired.values) {
      list.removeWhere(
        (p) =>
            _notificationId(p.media, p.mediaId, _slotDayBefore) == id ||
            _notificationId(p.media, p.mediaId, _slotHourBefore) == id,
      );
    }

    await _notificationsPlugin.cancel(id: id);
    await _removeReceivedNotificationDirect(id.toString());
    await _removeFromScheduledRegistryDirect([id.toString()]);
    _lastScheduledSignature = null;
  }

  Future<void> cancelNotificationById(int id) =>
      _synchronized(() => _cancelNotificationByIdDirect(id));

  /// Cancels platform notifications and resets the scheduled signature.
  /// Does NOT mutate _desired.
  Future<void> cancelAllNotifications() => _synchronized(() async {
    await _notificationsPlugin.cancelAll();
    _lastScheduledSignature = null;
  });

  /// Explicit user-intent clear-all flow: wipes desired titles, canceled state,
  /// platform notifications, and local history.
  Future<void> clearAllUserNotifications() => _synchronized(() async {
    _desired.clear();
    _canceledNotificationIds.clear();
    await _notificationsPlugin.cancelAll();
    _lastScheduledSignature = null;
    await _setHasUnread(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefReceivedHistory);
    await prefs.remove(_prefScheduledRegistry);
  });

  /// Returns all currently scheduled/pending notification items for display.
  Future<List<ScheduledNotificationDisplayItem>>
  getPendingNotifications() async {
    final Map<int, ScheduledNotificationDisplayItem> itemsById = {};

    // 1. Fetch platform-scheduled notification requests from local notifications plugin
    try {
      final platformRequests = await _notificationsPlugin
          .pendingNotificationRequests();
      for (final req in platformRequests) {
        if (req.title != null && req.body != null) {
          itemsById[req.id] = ScheduledNotificationDisplayItem(
            id: req.id,
            title: req.title!,
            body: req.body!,
            payload: req.payload,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch platform pending notifications: $e');
    }

    // 2. Supplement with desired notifications from watchlists
    final prefs = await SharedPreferences.getInstance();
    final notify1DayBefore = prefs.getBool(_prefNotify1DayBefore) ?? false;
    final now = DateTime.now();
    for (final entry in _desired.entries) {
      final media = entry.key;
      for (final pending in entry.value) {
        if (pending.releaseDateStr.isEmpty) continue;
        final releaseDate = _resolveReleaseDate(pending.releaseDateStr);
        if (releaseDate == null) continue;

        // Primary alert: 1 hour before release
        final hourBefore = releaseDate.subtract(const Duration(hours: 1));
        if (hourBefore.isAfter(now)) {
          final id = _notificationId(media, pending.mediaId, _slotHourBefore);
          itemsById.putIfAbsent(
            id,
            () => ScheduledNotificationDisplayItem(
              id: id,
              title: '${pending.title} (In 1 Hour)',
              body: pending.body.replaceAll('{time}', 'in 1 hour'),
              payload: _deepLinkFor(media, pending.mediaId),
              media: media,
              mediaId: pending.mediaId,
              scheduledDate: hourBefore,
            ),
          );
        }

        // Optional advance alert: 1 day before release
        if (notify1DayBefore) {
          final dayBefore = releaseDate.subtract(const Duration(days: 1));
          if (dayBefore.isAfter(now)) {
            final id = _notificationId(media, pending.mediaId, _slotDayBefore);
            itemsById.putIfAbsent(
              id,
              () => ScheduledNotificationDisplayItem(
                id: id,
                title: '${pending.title} (Tomorrow)',
                body: pending.body.replaceAll('{time}', 'tomorrow'),
                payload: _deepLinkFor(media, pending.mediaId),
                media: media,
                mediaId: pending.mediaId,
                scheduledDate: dayBefore,
              ),
            );
          }
        }
      }
    }

    final list = itemsById.values.toList();
    list.sort((a, b) {
      if (a.scheduledDate == null && b.scheduledDate == null) return 0;
      if (a.scheduledDate == null) return 1;
      if (b.scheduledDate == null) return -1;
      return a.scheduledDate!.compareTo(b.scheduledDate!);
    });

    // Soonest first, so the cap drops the most distant alerts rather than
    // whichever titles happened to sort last in the watchlist.
    if (list.length > _maxPending) {
      return list.take(_maxPending).toList();
    }
    return list;
  }

  /// Wipes all scheduled alerts and the desired set on sign-out.
  ///
  /// Without this the previous account's watchlist keeps firing notifications
  /// on a shared device: the cubits' streams close, so nothing resubmits and
  /// nothing would otherwise cancel what is already scheduled.
  Future<void> clearForSignOut() => _synchronized(() async {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _desired.clear();
    _canceledNotificationIds.clear();
    await _notificationsPlugin.cancelAll();
    _lastScheduledSignature = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefReceivedHistory);
    await prefs.remove(_prefScheduledRegistry);
  });

  /// Turns a TMDB date string into the release moment that alerts are offset
  /// back from — the alerts themselves fire a day or an hour before it.
  ///
  /// Date-only strings (`YYYY-MM-DD`) carry no air time, so they resolve to 9am
  /// local. Strings with a time component are parsed as-is — `DateTime.parse`
  /// yields a UTC instant for a trailing `Z`, which `TZDateTime.from` then
  /// converts correctly.
  DateTime? _resolveReleaseDate(String releaseDateStr) {
    final rawDate = DateTime.tryParse(releaseDateStr);
    if (rawDate == null) return null;
    if (releaseDateStr.length <= 10) {
      return DateTime(rawDate.year, rawDate.month, rawDate.day, 9, 0);
    }
    return rawDate;
  }

  /// Latest desired set per watchlist. Each cubit owns its own entry and
  /// overwrites it wholesale, so a title dropping out of a watchlist simply
  /// stops appearing here and gets cancelled on the next reconcile.
  final Map<NotificationMedia, List<PendingNotification>> _desired = {};

  Timer? _reconcileTimer;

  /// Fingerprint of the last set actually scheduled, so repeat emissions that
  /// change nothing don't trigger another round of platform calls.
  String? _lastScheduledSignature;

  /// Max pending notifications allowed. Once limit of 20 is reached,
  /// older notifications are removed in a FIFO manner.
  static const int _maxPending = 20;

  static const Duration _reconcileDebounce = Duration(milliseconds: 600);

  /// Replaces everything [media] wants notified, and schedules a reconcile.
  ///
  /// Callers pass their whole watchlist every time rather than individual
  /// titles: reconcile needs the complete picture to enforce [_maxPending]
  /// across both watchlists, and a full set makes stale entries self-cancelling.
  void submitTitles(NotificationMedia media, List<PendingNotification> titles) {
    _desired[media] = titles;
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(_reconcileDebounce, () {
      _reconcileTimer = null;
      reconcile();
    });
  }

  Future<void>? _inFlight;
  bool _rerunQueued = false;
  bool _rerunForce = false;

  /// Rebuilds the platform's pending set from [_desired].
  ///
  /// [force] skips the no-change fingerprint check — used after a settings
  /// change, where the desired titles are identical but what they expand into
  /// is not.
  ///
  /// Serialised deliberately. A reconcile cancels everything before
  /// rescheduling, so two overlapping runs can interleave into one wiping the
  /// other's freshly scheduled alerts while the fingerprint records success.
  /// Overlapping calls coalesce into a single follow-up pass instead.
  Future<void> reconcile({bool force = false}) => _synchronized(() {
    if (_inFlight != null) {
      _rerunQueued = true;
      _rerunForce = _rerunForce || force;
      return _inFlight!;
    }
    final future = _reconcileUntilSettled(force);
    _inFlight = future;
    return future;
  });

  Future<void> _reconcileUntilSettled(bool force) async {
    try {
      var runForce = force;
      while (true) {
        try {
          await _reconcileOnce(runForce);
        } catch (e) {
          // Reconcile is fire-and-forget from the debounce timer, so an escaping
          // error would surface as an unhandled async exception rather than
          // anything actionable. Drop the fingerprint so the next run retries
          // instead of matching stale state.
          _lastScheduledSignature = null;
          debugPrint('Notification reconcile failed: $e');
        }
        if (!_rerunQueued) break;
        _rerunQueued = false;
        runForce = _rerunForce;
        _rerunForce = false;
      }
    } finally {
      _inFlight = null;
      _rerunQueued = false;
      _rerunForce = false;
    }
  }

  Future<void> _reconcileOnce(bool force) async {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;

    if (force) {
      _lastScheduledSignature = null;
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.deleteNotificationChannel(
        channelId: AppConstants.notificationReleaseChannelId,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool(_prefNotificationsEnabled) ?? false;

    // The in-app preference is necessary but not sufficient — a user who
    // revoked notifications in system settings keeps the toggle showing "on",
    // and scheduling against a denied permission just fails silently.
    final permitted = notificationsEnabled && await hasSystemPermission();

    if (!permitted) {
      if (_lastScheduledSignature != 'blocked' || force) {
        await _notificationsPlugin.cancelAll();
        await prefs.remove(_prefScheduledRegistry);
        _lastScheduledSignature = 'blocked';
      }
      return;
    }

    // Preserve any alert that just reached or passed its fire time before rebuilding
    await _promoteFiredNotificationsDirect();

    final notify1DayBefore = prefs.getBool(_prefNotify1DayBefore) ?? false;
    final now = DateTime.now();

    // Expand every title into its alerts, dropping anything already past.
    final alerts = <_ScheduledAlert>[];
    for (final titles in _desired.values) {
      for (final pending in titles) {
        if (pending.releaseDateStr.isEmpty) continue;
        final releaseDate = _resolveReleaseDate(pending.releaseDateStr);
        if (releaseDate == null) continue;

        // Primary alert: 1 hour before release
        final hourBefore = releaseDate.subtract(const Duration(hours: 1));
        final hourBeforeId = _notificationId(
          pending.media,
          pending.mediaId,
          _slotHourBefore,
        );
        if (hourBefore.isAfter(now) &&
            !_canceledNotificationIds.contains(hourBeforeId)) {
          alerts.add(
            _ScheduledAlert(
              id: hourBeforeId,
              title: '${pending.title} (In 1 Hour)',
              body: pending.body.replaceAll('{time}', 'in 1 hour'),
              when: hourBefore,
              payload: _deepLinkFor(pending.media, pending.mediaId),
            ),
          );
        }

        // Optional advance alert: 1 day before release
        if (notify1DayBefore) {
          final dayBefore = releaseDate.subtract(const Duration(days: 1));
          final dayBeforeId = _notificationId(
            pending.media,
            pending.mediaId,
            _slotDayBefore,
          );
          if (dayBefore.isAfter(now) &&
              !_canceledNotificationIds.contains(dayBeforeId)) {
            alerts.add(
              _ScheduledAlert(
                id: dayBeforeId,
                title: '${pending.title} (Tomorrow)',
                body: pending.body.replaceAll('{time}', 'tomorrow'),
                when: dayBefore,
                payload: _deepLinkFor(pending.media, pending.mediaId),
              ),
            );
          }
        }
      }
    }

    // Soonest first, so the cap drops the most distant alerts rather than
    // whichever titles happened to sort last in the watchlist.
    alerts.sort((a, b) => a.when.compareTo(b.when));
    final capped = alerts.take(_maxPending).toList();

    final signature = capped
        .map((a) => '${a.id}@${a.when.millisecondsSinceEpoch}')
        .join(',');
    if (!force && signature == _lastScheduledSignature) return;

    // Clear and rebuild. Cancelling wholesale is what makes stale alerts —
    // a show that stopped airing, a movie already watched — disappear without
    // each caller having to track what it previously scheduled.
    await _notificationsPlugin.cancelAll();

    final scheduledAlerts = <_ScheduledAlert>[];
    for (final alert in capped) {
      // Per-alert so one failure can't abort the rest. Exact alarms can be
      // revoked on Android 12+, which makes zonedSchedule throw.
      final success = await _scheduleOne(
        id: alert.id,
        title: alert.title,
        body: alert.body,
        scheduledDate: alert.when,
        payload: alert.payload,
      );
      if (success) {
        scheduledAlerts.add(alert);
      }
    }

    // Keep the scheduled registry in sync with only successfully scheduled items
    final registryList = scheduledAlerts
        .map(
          (alert) => jsonEncode(
            _ScheduledRegistryItem(
              id: alert.id.toString(),
              title: alert.title,
              body: alert.body,
              payload: alert.payload,
              scheduledDate: alert.when,
            ).toJson(),
          ),
        )
        .toList();
    await prefs.setStringList(_prefScheduledRegistry, registryList);

    // Signature matches only what was actually successfully scheduled
    _lastScheduledSignature = scheduledAlerts
        .map((a) => '${a.id}@${a.when.millisecondsSinceEpoch}')
        .join(',');
  }
}
