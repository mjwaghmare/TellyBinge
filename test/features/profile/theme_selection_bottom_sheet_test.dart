import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/storage/settings_storage.dart';
import 'package:popverse/core/theme/cubit/theme_cubit.dart';
import 'package:popverse/features/profile/presentation/widgets/theme_selection_bottom_sheet.dart';

class _FakeSettingsStorage extends SettingsStorage {
  final Map<String, dynamic> _memory = {};

  @override
  Future<Map<String, dynamic>> readSettings() async => Map.from(_memory);

  @override
  Future<void> writeSetting(String key, dynamic value) async {
    _memory[key] = value;
  }
}

void main() {
  group('ThemeSelectionBottomSheet', () {
    late _FakeSettingsStorage fakeStorage;
    late ThemeCubit themeCubit;

    setUp(() {
      fakeStorage = _FakeSettingsStorage();
      themeCubit = ThemeCubit(
        storage: fakeStorage,
        initialThemeMode: ThemeMode.system,
        isOledInitial: false,
      );
    });

    tearDown(() {
      themeCubit.close();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: themeCubit,
            child: const ThemeSelectionBottomSheet(),
          ),
        ),
      );
    }

    testWidgets('renders Appearance title, subtitle, and all 3 theme options', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Choose how Popverse looks on your device'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('selecting Light mode updates theme cubit state', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeCubit.state.themeMode, equals(ThemeMode.light));
    });

    testWidgets('selecting Dark mode updates theme cubit state', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(themeCubit.state.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('selecting System mode updates theme cubit state', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await themeCubit.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(themeCubit.state.themeMode, equals(ThemeMode.system));
    });
  });
}
