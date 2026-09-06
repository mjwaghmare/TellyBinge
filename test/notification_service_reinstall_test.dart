import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      AppStorageKeys.appInstallTimestamp: nowMs,
    });
    methodCalls.clear();
    IOSFlutterLocalNotificationsPlugin.registerWith();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          methodCalls.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') return true;
          if (call.method == 'cancel') return null;
          return null;
        });

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    NotificationService.debugReleaseModeOverride = true;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    NotificationService.debugReleaseModeOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NotificationService iOS reinstall reminder queue serialization', () {
    test(
      'admin scheduling sets scheduled flag to true and issues zonedSchedule calls',
      () async {
        final service = NotificationService();
        await service.scheduleReinstallReminderIfNeeded(isAdmin: true);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(AppStorageKeys.reinstallReminderScheduled),
          isTrue,
        );
        expect(
          methodCalls.map((call) => call.method),
          contains('zonedSchedule'),
        );
      },
    );

    test(
      'admin to non-admin transition serializes, cancels after scheduling, and leaves flag false',
      () async {
        final service = NotificationService();
        final prefs = await SharedPreferences.getInstance();

        // Dispatch admin scheduling followed immediately by non-admin transition
        // without waiting for the first future to complete.
        final f1 = service.scheduleReinstallReminderIfNeeded(isAdmin: true);
        final f2 = service.scheduleReinstallReminderIfNeeded(isAdmin: false);

        await Future.wait([f1, f2]);

        // Due to _operationQueue serialization, f2 runs after f1 finishes scheduling,
        // ensuring cancellation cannot race with scheduling.
        expect(
          prefs.getBool(AppStorageKeys.reinstallReminderScheduled),
          isFalse,
        );

        final methods = methodCalls.map((c) => c.method).toList();
        expect(methods, contains('zonedSchedule'));
        expect(methods, contains('cancel'));

        final firstZonedIndex = methods.indexOf('zonedSchedule');
        final lastCancelIndex = methods.lastIndexOf('cancel');

        expect(firstZonedIndex, isNot(-1));
        expect(lastCancelIndex, isNot(-1));
        expect(lastCancelIndex, greaterThan(firstZonedIndex));
      },
    );

    test(
      'cancelReinstallReminders cancels notifications and clears scheduled flag',
      () async {
        final service = NotificationService();
        final prefs = await SharedPreferences.getInstance();

        await service.scheduleReinstallReminderIfNeeded(isAdmin: true);
        expect(
          prefs.getBool(AppStorageKeys.reinstallReminderScheduled),
          isTrue,
        );
        expect(
          methodCalls.map((call) => call.method),
          contains('zonedSchedule'),
        );

        methodCalls.clear();
        await service.cancelReinstallReminders();

        expect(
          prefs.getBool(AppStorageKeys.reinstallReminderScheduled),
          isFalse,
        );
        expect(
          methodCalls.map((call) => call.method),
          contains('cancel'),
        );
      },
    );
  });
}
