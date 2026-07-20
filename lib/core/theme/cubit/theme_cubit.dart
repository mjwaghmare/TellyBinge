import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../storage/settings_storage.dart';

class ThemeState extends Equatable {
  final bool isDarkMode;
  final bool isOledDarkMode;

  const ThemeState({
    required this.isDarkMode,
    required this.isOledDarkMode,
  });

  @override
  List<Object?> get props => [isDarkMode, isOledDarkMode];
}

class ThemeCubit extends Cubit<ThemeState> {
  final SettingsStorage storage;

  ThemeCubit({
    required this.storage,
    required bool isDarkInitial,
    required bool isOledInitial,
  }) : super(ThemeState(isDarkMode: isDarkInitial, isOledDarkMode: isOledInitial));

  Future<void> toggleDarkMode(bool value) async {
    await storage.writeSetting('dark_mode', value);
    emit(ThemeState(isDarkMode: value, isOledDarkMode: state.isOledDarkMode));
  }

  Future<void> toggleOledDarkMode(bool value) async {
    await storage.writeSetting('oled_dark_mode', value);
    emit(ThemeState(isDarkMode: state.isDarkMode, isOledDarkMode: value));
  }
}
