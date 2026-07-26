import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/notification_service.dart';

class SettingsState extends Equatable {
  final bool allowAdultContent;
  final bool notificationsEnabled;
  final bool notify1HourBefore;

  const SettingsState({
    this.allowAdultContent = false,
    this.notificationsEnabled = false,
    this.notify1HourBefore = false,
  });

  SettingsState copyWith({
    bool? allowAdultContent,
    bool? notificationsEnabled,
    bool? notify1HourBefore,
  }) {
    return SettingsState(
      allowAdultContent: allowAdultContent ?? this.allowAdultContent,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notify1HourBefore: notify1HourBefore ?? this.notify1HourBefore,
    );
  }

  @override
  List<Object> get props => [
        allowAdultContent,
        notificationsEnabled,
        notify1HourBefore,
      ];
}

class SettingsCubit extends Cubit<SettingsState> {
  final SharedPreferences prefs;
  final TmdbClient tmdbClient;
  static const String _adultContentKey = 'allow_adult_content';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notify1HourBeforeKey = 'notify_1_hour_before';

  SettingsCubit({
    required this.prefs,
    required this.tmdbClient,
  }) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final allowAdult = prefs.getBool(_adultContentKey) ?? false;
    final notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;
    final notify1HourBefore = prefs.getBool(_notify1HourBeforeKey) ?? false;
    
    tmdbClient.allowAdultContent = allowAdult;
    emit(SettingsState(
      allowAdultContent: allowAdult,
      notificationsEnabled: notificationsEnabled,
      notify1HourBefore: notify1HourBefore,
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
    } else {
      await NotificationService().cancelAllNotifications();
    }
  }

  Future<void> toggleNotify1HourBefore(bool value) async {
    await prefs.setBool(_notify1HourBeforeKey, value);
    emit(state.copyWith(notify1HourBefore: value));
  }
}
