import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/notification_service.dart';

class SettingsState extends Equatable {
  final bool allowAdultContent;
  final bool notificationsEnabled;
  final bool notify1HourBefore;
  final bool notify1DayBefore;

  const SettingsState({
    this.allowAdultContent = false,
    this.notificationsEnabled = true,
    this.notify1HourBefore = false,
    this.notify1DayBefore = true,
  });

  SettingsState copyWith({
    bool? allowAdultContent,
    bool? notificationsEnabled,
    bool? notify1HourBefore,
    bool? notify1DayBefore,
  }) {
    return SettingsState(
      allowAdultContent: allowAdultContent ?? this.allowAdultContent,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notify1HourBefore: notify1HourBefore ?? this.notify1HourBefore,
      notify1DayBefore: notify1DayBefore ?? this.notify1DayBefore,
    );
  }

  @override
  List<Object> get props => [
        allowAdultContent,
        notificationsEnabled,
        notify1HourBefore,
        notify1DayBefore,
      ];
}

class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences prefs;
  final TmdbClient tmdbClient;
  static const String _adultContentKey = 'allow_adult_content';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notify1HourBeforeKey = 'notify_1_hour_before';
  static const String _notify1DayBeforeKey = 'notify_1_day_before';

  SettingsCubit({
    required this.prefs,
    required this.tmdbClient,
  }) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final allowAdult = prefs.getBool(_adultContentKey) ?? false;
    final notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    final notify1HourBefore = prefs.getBool(_notify1HourBeforeKey) ?? false;
    final notify1DayBefore = prefs.getBool(_notify1DayBeforeKey) ?? true;
    
    tmdbClient.allowAdultContent = allowAdult;
    emit(SettingsState(
      allowAdultContent: allowAdult,
      notificationsEnabled: notificationsEnabled,
      notify1HourBefore: notify1HourBefore,
      notify1DayBefore: notify1DayBefore,
    ));
  }

  Future<void> toggleAdultContent(bool value) async {
    await prefs.setBool(_adultContentKey, value);
    tmdbClient.allowAdultContent = value;
    emit(state.copyWith(allowAdultContent: value));
  }
  
  Future<void> toggleNotifications(bool value) async {
    await prefs.setBool(_notificationsEnabledKey, value);
    emit(state.copyWith(notificationsEnabled: value));
    if (value) {
      await NotificationService().requestPermissions();
    }
  }

  Future<void> toggleNotify1HourBefore(bool value) async {
    await prefs.setBool(_notify1HourBeforeKey, value);
    emit(state.copyWith(notify1HourBefore: value));
  }

  Future<void> toggleNotify1DayBefore(bool value) async {
    await prefs.setBool(_notify1DayBeforeKey, value);
    emit(state.copyWith(notify1DayBefore: value));
  }
}
