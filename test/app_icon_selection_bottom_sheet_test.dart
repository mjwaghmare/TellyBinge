import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/models/app_icon_option.dart';
import 'package:popverse/core/services/app_icon_service.dart';
import 'package:popverse/features/profile/presentation/cubit/app_icon_cubit.dart';
import 'package:popverse/features/profile/presentation/widgets/app_icon_selection_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAppIconService extends AppIconService {
  AppIconOption current;
  bool shouldSucceed;

  FakeAppIconService({
    this.current = AppIconOption.defaultIcon,
    this.shouldSucceed = true,
  });

  @override
  Future<bool> get supportsAlternateIcons async => true;

  @override
  Future<AppIconOption> getCurrentIcon() async => current;

  @override
  Future<bool> setAppIcon(AppIconOption option) async {
    if (shouldSucceed) {
      current = option;
      return true;
    }
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({required AppIconCubit cubit}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const AppIconSelectionBottomSheet(),
                ),
              );
            },
            child: const Text('Open App Icon Sheet'),
          ),
        ),
      ),
    );
  }

  testWidgets('sheet closes when new app icon is selected and applied successfully', (tester) async {
    final service = FakeAppIconService(
      current: AppIconOption.defaultIcon,
      shouldSucceed: true,
    );
    final cubit = AppIconCubit(service: service, isProUser: true);

    await tester.pumpWidget(buildTestApp(cubit: cubit));
    await tester.tap(find.text('Open App Icon Sheet'));
    await tester.pumpAndSettle();

    // Bottom sheet is visible
    expect(find.text('Application Icon'), findsOneWidget);

    // Tap on a different icon (e.g. Midnight)
    await tester.tap(find.text(AppIconOption.midnight.title));
    await tester.pumpAndSettle();

    // The bottom sheet should be closed!
    expect(find.text('Application Icon'), findsNothing);
    expect(cubit.state.currentIcon, AppIconOption.midnight);

    await cubit.close();
  });

  testWidgets('sheet remains open when tapping the already selected icon', (tester) async {
    final service = FakeAppIconService(
      current: AppIconOption.defaultIcon,
      shouldSucceed: true,
    );
    final cubit = AppIconCubit(service: service, isProUser: true);

    await tester.pumpWidget(buildTestApp(cubit: cubit));
    await tester.tap(find.text('Open App Icon Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Application Icon'), findsOneWidget);

    // Tap on the default icon (already selected)
    await tester.tap(find.text(AppIconOption.defaultIcon.title));
    await tester.pumpAndSettle();

    // Sheet remains open
    expect(find.text('Application Icon'), findsOneWidget);

    await cubit.close();
  });

  testWidgets('sheet remains open when icon update fails', (tester) async {
    final service = FakeAppIconService(
      current: AppIconOption.defaultIcon,
      shouldSucceed: false,
    );
    final cubit = AppIconCubit(service: service, isProUser: true);

    await tester.pumpWidget(buildTestApp(cubit: cubit));
    await tester.tap(find.text('Open App Icon Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Application Icon'), findsOneWidget);

    // Tap a new icon, but service returns false
    await tester.tap(find.text(AppIconOption.midnight.title));
    await tester.pumpAndSettle();

    // Sheet remains open, error snackbar is shown
    expect(find.text('Application Icon'), findsOneWidget);
    expect(cubit.state.errorMessage, isNotNull);

    await cubit.close();
  });
}
