import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../storage/settings_storage.dart';

class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final bool isOledDarkMode;

  const ThemeState({required this.themeMode, required this.isOledDarkMode});

  bool get isDarkMode => themeMode == ThemeMode.dark;

  @override
  List<Object?> get props => [themeMode, isOledDarkMode];
}

class ThemeCubit extends Cubit<ThemeState> {
  final SettingsStorage storage;

  ThemeCubit({
    required this.storage,
    required ThemeMode initialThemeMode,
    required bool isOledInitial,
  }) : super(
         ThemeState(themeMode: initialThemeMode, isOledDarkMode: isOledInitial),
       );

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;

    // Optimistic UI update: emit immediately for instant theme switch.
    emit(ThemeState(themeMode: mode, isOledDarkMode: state.isOledDarkMode));

    // Persist in background without blocking the UI.
    unawaited(_persistThemeMode(mode));
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    final modeString = switch (mode) {
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
    };
    await storage.writeSetting('theme_mode', modeString);
    await storage.writeSetting('dark_mode', mode == ThemeMode.dark);
  }

  Future<void> toggleDarkMode(bool value) async {
    final mode = value ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(mode);
  }

  Future<void> toggleOledDarkMode(bool value) async {
    await storage.writeSetting('oled_dark_mode', value);
    emit(ThemeState(themeMode: state.themeMode, isOledDarkMode: value));
  }
}
