import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      '🍿 Up Next: $showName',
      '⏰ Airing Soon: $showName',
      '📺 New Episode: $showName',
      '🍿 Binge Time: $showName',
      '📺 Ready: $showName',
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
      '🎬 Premiere: $movieTitle',
      '🍿 Release Alert: $movieTitle',
      '🎬 Movie Night: $movieTitle',
      '🍿 Coming Soon: $movieTitle',
      '🌟 Premiering: $movieTitle',
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

  /// Initializes unread status from SharedPreferences.
  Future<void> _initUnreadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    hasUnreadNotifier.value =
        prefs.getBool('has_unread_notifications') ?? false;
  }

  /// Sets unread notification state and updates listeners & SharedPreferences.
  Future<void> _setHasUnread(bool value) async {
    hasUnreadNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_unread_notifications', value);
  }

  /// Marks all notifications as read.
  Future<void> markNotificationsAsRead() async {
    await _setHasUnread(false);
  }

  /// Schedules a 6th-day reinstall reminder notification ONLY on iOS Release builds
  /// for free-tier personal developer provisioning expiration.
  Future<void> scheduleReinstallReminderIfNeeded() async {
    if (!kReleaseMode || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    int? installTimestamp = prefs.getInt('app_install_timestamp');
    if (installTimestamp == null) {
      installTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('app_install_timestamp', installTimestamp);
    }

    final alreadyScheduled =
        prefs.getBool('reinstall_reminder_scheduled') ?? false;
    if (alreadyScheduled) {
      return;
    }

    final installDate = DateTime.fromMillisecondsSinceEpoch(installTimestamp);
    final reminderDate = installDate.add(const Duration(days: 6));

    if (reminderDate.isAfter(DateTime.now())) {
      try {
        await _scheduleOne(
          id: _reinstallNotificationId,
          title: "⏳ Time's Almost Up!",
          body:
              "Free profile expires tomorrow. Connect to Xcode and rebuild now! 💻",
          scheduledDate: reminderDate,
        );
        await prefs.setBool('reinstall_reminder_scheduled', true);
      } catch (e) {
        debugPrint('Failed to schedule reinstall reminder: $e');
      }
    }
  }

  Future<void> initialize() async {
    await _initUnreadStatus();
    await scheduleReinstallReminderIfNeeded();
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Fallback: preserve existing initialized location if platform timezone lookup fails
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

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
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
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
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          importance: Importance.max,
          priority: Priority.max,
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

    await _notificationsPlugin.show(
      id: _testNotificationId,
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
      notificationDetails: platformChannelSpecifics,
    );

    await saveReceivedNotification(
      id: _testNotificationId.toString(),
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
    );
  }

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // Don't schedule in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'release_channel',
          'Release Notifications',
          importance: Importance.max,
          priority: Priority.max,
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

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Track canceled notification IDs for durable suppression across reconciles.
  final Set<int> _canceledNotificationIds = {};

  /// Drops one title's alerts immediately, without waiting for its watchlist
  /// stream to round-trip and trigger a reconcile.
  ///
  /// Reconcile would cancel these anyway once the title leaves the submitted
  /// list; this just makes removal feel instant. The stored signature is
  /// cleared because the platform no longer matches what reconcile last
  /// scheduled, and without that the next run could no-op on a stale match.
  Future<void> cancelNotification(NotificationMedia media, int id) async {
    final dayBeforeId = _notificationId(media, id, _slotDayBefore);
    final hourBeforeId = _notificationId(media, id, _slotHourBefore);

    _canceledNotificationIds.add(dayBeforeId);
    _canceledNotificationIds.add(hourBeforeId);

    if (_desired.containsKey(media)) {
      _desired[media]!.removeWhere((p) => p.mediaId == id);
    }

    await _notificationsPlugin.cancel(id: dayBeforeId);
    await _notificationsPlugin.cancel(id: hourBeforeId);
    _lastScheduledSignature = null;
  }

  static const int _maxReceivedHistory = 20;

  /// Saves a notification that was received/pushed to local history.
  /// Enforces FIFO rule: max 20 items.
  Future<void> saveReceivedNotification({
    required String title,
    required String body,
    String? payload,
    String? id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('received_notifications_history') ?? [];

    final newItem = ReceivedNotificationItem(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      payload: payload,
      timestamp: DateTime.now().toIso8601String(),
    );

    final updatedList = <String>[jsonEncode(newItem.toJson()), ...rawList];

    if (updatedList.length > _maxReceivedHistory) {
      updatedList.removeRange(_maxReceivedHistory, updatedList.length);
    }

    await prefs.setStringList('received_notifications_history', updatedList);
    await _setHasUnread(true);
  }

  /// Retrieves received notifications history (most recent first, max 20).
  Future<List<ReceivedNotificationItem>> getReceivedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('received_notifications_history') ?? [];

    final items = <ReceivedNotificationItem>[];
    for (final jsonStr in rawList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        items.add(ReceivedNotificationItem.fromJson(map));
      } catch (_) {}
    }
    return items;
  }

  /// Removes a single received notification by ID from history.
  Future<void> removeReceivedNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('received_notifications_history') ?? [];
    final updatedList = <String>[];

    for (final jsonStr in rawList) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map['id']?.toString() != id) {
          updatedList.add(jsonStr);
        }
      } catch (_) {}
    }

    await prefs.setStringList('received_notifications_history', updatedList);
    if (updatedList.isEmpty) {
      await _setHasUnread(false);
    }
  }

  Future<void> cancelNotificationById(int id) async {
    _canceledNotificationIds.add(id);

    for (final list in _desired.values) {
      list.removeWhere(
        (p) =>
            _notificationId(p.media, p.mediaId, _slotDayBefore) == id ||
            _notificationId(p.media, p.mediaId, _slotHourBefore) == id,
      );
    }

    await _notificationsPlugin.cancel(id: id);
    await removeReceivedNotification(id.toString());
    _lastScheduledSignature = null;
  }

  /// Cancels platform notifications and resets the scheduled signature.
  /// Does NOT mutate _desired.
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    _lastScheduledSignature = null;
  }

  /// Explicit user-intent clear-all flow: wipes desired titles, canceled state,
  /// platform notifications, and local history.
  Future<void> clearAllUserNotifications() async {
    _desired.clear();
    _canceledNotificationIds.clear();
    await cancelAllNotifications();
    await _setHasUnread(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('received_notifications_history');
  }

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
    final now = DateTime.now();
    for (final entry in _desired.entries) {
      final media = entry.key;
      for (final pending in entry.value) {
        if (pending.releaseDateStr.isEmpty) continue;
        final releaseDate = _resolveReleaseDate(pending.releaseDateStr);
        if (releaseDate == null) continue;

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
  Future<void> clearForSignOut() async {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _desired.clear();
    _canceledNotificationIds.clear();
    await cancelAllNotifications();
    _lastScheduledSignature = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('received_notifications_history');
  }

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
  Future<void> reconcile({bool force = false}) {
    if (_inFlight != null) {
      _rerunQueued = true;
      _rerunForce = _rerunForce || force;
      return _inFlight!;
    }
    final future = _reconcileUntilSettled(force);
    _inFlight = future;
    return future;
  }

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

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('notifications_enabled') ?? false;

    // The in-app preference is necessary but not sufficient — a user who
    // revoked notifications in system settings keeps the toggle showing "on",
    // and scheduling against a denied permission just fails silently.
    final permitted = notificationsEnabled && await hasSystemPermission();

    if (!permitted) {
      if (_lastScheduledSignature != 'blocked' || force) {
        await cancelAllNotifications();
        _lastScheduledSignature = 'blocked';
      }
      return;
    }

    final notify1HourBefore = prefs.getBool('notify_1_hour_before') ?? false;
    final now = DateTime.now();

    // Expand every title into its alerts, dropping anything already past.
    final alerts = <_ScheduledAlert>[];
    for (final titles in _desired.values) {
      for (final pending in titles) {
        if (pending.releaseDateStr.isEmpty) continue;
        final releaseDate = _resolveReleaseDate(pending.releaseDateStr);
        if (releaseDate == null) continue;

        // The default alert lands a day ahead so there is runway to plan around
        // the release. A title added after that moment has passed simply gets
        // no day-before alert — the hour-before one, if enabled, still fires.
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

        if (notify1HourBefore) {
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
    await cancelAllNotifications();

    for (final alert in capped) {
      // Per-alert so one failure can't abort the rest. Exact alarms can be
      // revoked on Android 12+, which makes zonedSchedule throw.
      try {
        await _scheduleOne(
          id: alert.id,
          title: alert.title,
          body: alert.body,
          scheduledDate: alert.when,
          payload: alert.payload,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification ${alert.id}: $e');
      }
    }

    _lastScheduledSignature = signature;
  }
}
