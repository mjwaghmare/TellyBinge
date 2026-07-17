import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../storage/settings_storage.dart';

class ThemeState extends Equatable {
  final bool isOledDarkMode;

  const ThemeState({required this.isOledDarkMode});

  @override
  List<Object?> get props => [isOledDarkMode];
}

class ThemeCubit extends Cubit<ThemeState> {
  final SettingsStorage storage;

  ThemeCubit({required this.storage, required bool isOledInitial})
      : super(ThemeState(isOledDarkMode: isOledInitial));

  Future<void> toggleOledDarkMode(bool value) async {
    await storage.writeSetting('oled_dark_mode', value);
    emit(ThemeState(isOledDarkMode: value));
  }
}
