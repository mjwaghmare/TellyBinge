import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../onboarding/data/onboarding_storage.dart';

class SettingsState extends Equatable {
  final bool allowAdultContent;
  final bool notificationsEnabled;
  final bool notify1HourBefore;
  final bool notify1DayBefore;
  final bool resetOnboarding;

  const SettingsState({
    this.allowAdultContent = false,
    this.notificationsEnabled = false,
    this.notify1HourBefore = false,
    this.notify1DayBefore = true,
    this.resetOnboarding = false,
  });

  SettingsState copyWith({
    bool? allowAdultContent,
    bool? notificationsEnabled,
    bool? notify1HourBefore,
    bool? notify1DayBefore,
    bool? resetOnboarding,
  }) {
    return SettingsState(
      allowAdultContent: allowAdultContent ?? this.allowAdultContent,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notify1HourBefore: notify1HourBefore ?? this.notify1HourBefore,
      notify1DayBefore: notify1DayBefore ?? this.notify1DayBefore,
      resetOnboarding: resetOnboarding ?? this.resetOnboarding,
    );
  }

  @override
  List<Object> get props => [
    allowAdultContent,
    notificationsEnabled,
    notify1HourBefore,
    notify1DayBefore,
    resetOnboarding,
  ];
}

class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences prefs;
  final TmdbClient tmdbClient;
  static const String _adultContentKey = 'allow_adult_content';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notify1HourBeforeKey = 'notify_1_hour_before';
  static const String _notify1DayBeforeKey = 'notify_1_day_before';

  SettingsCubit({required this.prefs, required this.tmdbClient})
    : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final allowAdult = prefs.getBool(_adultContentKey) ?? false;
    final notificationsEnabled =
        prefs.getBool(_notificationsEnabledKey) ?? false;
    final notify1HourBefore = prefs.getBool(_notify1HourBeforeKey) ?? false;
    final notify1DayBefore = prefs.getBool(_notify1DayBeforeKey) ?? true;
    final hasSeenOnboarding = prefs.getBool(OnboardingStorage.seenKey) ?? false;

    tmdbClient.allowAdultContent = allowAdult;
    emit(
      SettingsState(
        allowAdultContent: allowAdult,
        notificationsEnabled: notificationsEnabled,
        notify1HourBefore: notify1HourBefore,
        notify1DayBefore: notify1DayBefore,
        resetOnboarding: !hasSeenOnboarding,
      ),
    );
  }

  Future<void> toggleAdultContent(bool value) async {
    await prefs.setBool(_adultContentKey, value);
    tmdbClient.allowAdultContent = value;
    emit(state.copyWith(allowAdultContent: value));
  }

  Future<void> toggleNotifications(bool value) async {
    if (value) {
      // If the OS refuses, don't leave a switch claiming notifications are on
      // while reconcile silently blocks every schedule.
      final granted = await NotificationService().requestPermissions();
      if (!granted) {
        await prefs.setBool(_notificationsEnabledKey, false);
        emit(state.copyWith(notificationsEnabled: false));
        await NotificationService().reconcile(force: true);
        return;
      }
    }
    await prefs.setBool(_notificationsEnabledKey, value);
    emit(state.copyWith(notificationsEnabled: value));
    // Reconcile either way: switching off cancels everything, switching back on
    // rebuilds from the watchlists already submitted. Without this, re-enabling
    // left the user with nothing pending until a watchlist stream happened to
    // emit. Forced because the desired titles haven't changed — only what they
    // expand into has.
    await NotificationService().reconcile(force: true);
  }

  Future<void> toggleNotify1HourBefore(bool value) async {
    await prefs.setBool(_notify1HourBeforeKey, value);
    emit(state.copyWith(notify1HourBefore: value));
    // Turning this off has to actively cancel the hour-before alerts already
    // scheduled, not just stop creating new ones.
    await NotificationService().reconcile(force: true);
  }

  Future<void> toggleNotify1DayBefore(bool value) async {
    await prefs.setBool(_notify1DayBeforeKey, value);
    emit(state.copyWith(notify1DayBefore: value));
    await NotificationService().reconcile(force: true);
  }

  Future<void> toggleResetOnboarding(bool value) async {
    await prefs.setBool(OnboardingStorage.seenKey, !value);
    emit(state.copyWith(resetOnboarding: value));
  }
}
