/// Centralized keys for local storage (SharedPreferences).
class AppStorageKeys {
  AppStorageKeys._();

  // Onboarding
  static const String hasSeenOnboarding = 'has_seen_onboarding';

  // Settings & Preferences
  static const String allowAdultContent = 'allow_adult_content';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String notify1HourBefore = 'notify_1_hour_before';
  static const String notify1DayBefore = 'notify_1_day_before';
  static const String selectedAppIcon = 'selected_app_icon';
  static const String hapticsEnabled = 'haptics_enabled';
  static const String reducedMotionEnabled = 'reduced_motion_enabled';

  // Notification Service State
  static const String hasUnreadNotifications = 'has_unread_notifications';
  static const String scheduledNotificationsRegistry =
      'scheduled_notifications_registry';
  static const String receivedNotificationsHistory =
      'received_notifications_history';
  static const String lastActiveTimezone = 'last_active_timezone';
  static const String appInstallTimestamp = 'app_install_timestamp';
  static const String reinstallReminderScheduled =
      'reinstall_reminder_scheduled';
  static const String reinstallReminderBuildTs = 'reinstall_reminder_build_ts';

  // App Update Snooze
  static const String updateSnoozedAt = 'app_update_snoozed_at';
  static const String updateSnoozedVersion = 'app_update_snoozed_version';

  // Achievements
  static const String unlockedAchievementsPrefix = 'unlocked_achievements_';
}
