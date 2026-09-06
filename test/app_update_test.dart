import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/constants/app_constants.dart';
import 'package:popverse/core/models/app_version_info.dart';
import 'package:popverse/core/services/app_update_service.dart';
import 'package:popverse/core/widgets/app_update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersionInfo', () {
    test('compareVersions handles various semver formats', () {
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.0'), 0);
      expect(AppVersionInfo.compareVersions('v1.0.0', '1.0.0'), 0);
      expect(AppVersionInfo.compareVersions('1.0.0+5', '1.0.0'), 0);
      expect(AppVersionInfo.compareVersions('1.0.0-beta', '1.0.0'), 0);

      expect(AppVersionInfo.compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(AppVersionInfo.compareVersions('1.0.1', '1.0.0'), greaterThan(0));

      expect(AppVersionInfo.compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(AppVersionInfo.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(AppVersionInfo.compareVersions('1.0', '1.0.1'), lessThan(0));
      expect(AppVersionInfo.compareVersions('1.0.0', '1.0'), 0);
    });

    test('fromMap parses version and is_optional fields', () {
      final fromSimple = AppVersionInfo.fromMap({
        'version': '1.2.0',
        'is_optional': true,
        'title': 'New Update',
      });
      expect(fromSimple.latestVersion, '1.2.0');
      expect(fromSimple.isOptional, isTrue);

      final fromForce = AppVersionInfo.fromMap({
        'version': '2.0.0',
        'is_optional': false,
      });
      expect(fromForce.latestVersion, '2.0.0');
      expect(fromForce.isOptional, isFalse);
    });

    test('getUpdateType returns force when isOptional is false', () {
      const info = AppVersionInfo(latestVersion: '2.0.0', isOptional: false);

      expect(info.getUpdateType('1.0.0'), AppUpdateType.force);
      expect(info.getUpdateType('1.9.9'), AppUpdateType.force);
    });

    test('getUpdateType returns optional when isOptional is true', () {
      const info = AppVersionInfo(latestVersion: '2.0.0', isOptional: true);

      expect(info.getUpdateType('1.0.0'), AppUpdateType.optional);
      expect(info.getUpdateType('1.9.9'), AppUpdateType.optional);
    });

    test('getUpdateType returns none when up to date or update disabled', () {
      const info = AppVersionInfo(latestVersion: '2.0.0', isOptional: false);

      expect(info.getUpdateType('2.0.0'), AppUpdateType.none);
      expect(info.getUpdateType('2.0.1'), AppUpdateType.none);

      const disabledInfo = AppVersionInfo(
        latestVersion: '2.0.0',
        isOptional: false,
        isUpdateEnabled: false,
      );
      expect(disabledInfo.getUpdateType('1.0.0'), AppUpdateType.none);
    });
  });

  group('AppUpdateService 7-Day Snooze Logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isUpdateSnoozed returns false when not snoozed', () async {
      final prefs = await SharedPreferences.getInstance();
      final snoozed = await AppUpdateService.instance.isUpdateSnoozed(
        '1.2.0',
        prefs: prefs,
      );
      expect(snoozed, isFalse);
    });

    test('snoozeUpdate stores timestamp and snoozes for 7 days', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppUpdateService.instance.snoozeUpdate('1.2.0', prefs: prefs);

      final snoozed = await AppUpdateService.instance.isUpdateSnoozed(
        '1.2.0',
        prefs: prefs,
      );
      expect(snoozed, isTrue);
    });

    test('isUpdateSnoozed returns false when 7 days have elapsed', () async {
      final prefs = await SharedPreferences.getInstance();
      final eightDaysAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 8),
      );

      await prefs.setString(
        AppUpdateService.prefSnoozedAt,
        eightDaysAgo.toIso8601String(),
      );
      await prefs.setString(AppUpdateService.prefSnoozedVersion, '1.2.0');

      final snoozed = await AppUpdateService.instance.isUpdateSnoozed(
        '1.2.0',
        prefs: prefs,
      );
      expect(snoozed, isFalse);
    });

    test(
      'isUpdateSnoozed returns false when a newer version is released',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await AppUpdateService.instance.snoozeUpdate('1.2.0', prefs: prefs);

        // User snoozed 1.2.0, but server now has 1.3.0
        final snoozed = await AppUpdateService.instance.isUpdateSnoozed(
          '1.3.0',
          prefs: prefs,
        );
        expect(snoozed, isFalse);
      },
    );

    test('clearSnooze removes snooze keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await AppUpdateService.instance.snoozeUpdate('1.2.0', prefs: prefs);
      expect(
        await AppUpdateService.instance.isUpdateSnoozed('1.2.0', prefs: prefs),
        isTrue,
      );

      await AppUpdateService.instance.clearSnooze(prefs: prefs);
      expect(
        await AppUpdateService.instance.isUpdateSnoozed('1.2.0', prefs: prefs),
        isFalse,
      );
    });
  });

  group('AppUpdateDialog UI', () {
    testWidgets('renders Optional update with Later and Update buttons', (
      tester,
    ) async {
      bool updateClicked = false;
      bool laterClicked = false;

      const versionInfo = AppVersionInfo(
        latestVersion: '1.5.0',
        isOptional: true,
        title: 'Exciting New Features!',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              versionInfo: versionInfo,
              installedVersion: '1.2.0',
              isForceUpdate: false,
              onUpdate: () => updateClicked = true,
              onLater: () => laterClicked = true,
            ),
          ),
        ),
      );

      expect(find.text(AppConstants.updateAvailableTitle), findsOneWidget);
      expect(
        find.text(AppConstants.optionalUpdateMessage),
        findsOneWidget,
      );
      expect(find.text(AppConstants.updateLaterButtonLabel), findsOneWidget);
      expect(find.text(AppConstants.updateButtonLabel), findsOneWidget);

      await tester.tap(find.text(AppConstants.updateButtonLabel));
      expect(updateClicked, isTrue);

      await tester.tap(find.text(AppConstants.updateLaterButtonLabel));
      expect(laterClicked, isTrue);
    });

    testWidgets('renders Force update with only Update Now button', (
      tester,
    ) async {
      bool updateClicked = false;

      const versionInfo = AppVersionInfo(
        latestVersion: '2.0.0',
        isOptional: false,
        title: 'Mandatory Update',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUpdateDialog(
              versionInfo: versionInfo,
              installedVersion: '1.0.0',
              isForceUpdate: true,
              onUpdate: () => updateClicked = true,
            ),
          ),
        ),
      );

      expect(find.text(AppConstants.updateAvailableTitle), findsOneWidget);
      expect(
        find.text(AppConstants.forceUpdateMessage),
        findsOneWidget,
      );
      expect(find.text(AppConstants.updateNowButtonLabel), findsOneWidget);
      expect(find.text(AppConstants.updateLaterButtonLabel), findsNothing);

      // Verify PopScope cannot pop
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      await tester.tap(find.text(AppConstants.updateNowButtonLabel));
      expect(updateClicked, isTrue);
    });
  });
}
