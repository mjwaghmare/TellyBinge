import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/services/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> platformCalls = [];

  setUp(() {
    platformCalls.clear();
    AppHaptics.isEnabled = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppHaptics.isEnabled = true;
  });

  group('AppHaptics', () {
    test('isEnabled defaults to true and can be modified', () {
      expect(AppHaptics.isEnabled, isTrue);
      AppHaptics.isEnabled = false;
      expect(AppHaptics.isEnabled, isFalse);
      AppHaptics.isEnabled = true;
      expect(AppHaptics.isEnabled, isTrue);
    });

    test('calls invoke platform channel when isEnabled is true', () async {
      AppHaptics.isEnabled = true;

      await AppHaptics.lightImpact();
      expect(platformCalls, hasLength(1));
      expect(platformCalls.last.method, 'HapticFeedback.vibrate');
      expect(platformCalls.last.arguments, 'HapticFeedbackType.lightImpact');

      await AppHaptics.mediumImpact();
      expect(platformCalls, hasLength(2));
      expect(platformCalls.last.method, 'HapticFeedback.vibrate');
      expect(platformCalls.last.arguments, 'HapticFeedbackType.mediumImpact');

      await AppHaptics.heavyImpact();
      expect(platformCalls, hasLength(3));
      expect(platformCalls.last.method, 'HapticFeedback.vibrate');
      expect(platformCalls.last.arguments, 'HapticFeedbackType.heavyImpact');

      await AppHaptics.selectionClick();
      expect(platformCalls, hasLength(4));
      expect(platformCalls.last.method, 'HapticFeedback.vibrate');
      expect(platformCalls.last.arguments, 'HapticFeedbackType.selectionClick');

      await AppHaptics.vibrate();
      expect(platformCalls, hasLength(5));
      expect(platformCalls.last.method, 'HapticFeedback.vibrate');
    });

    test('calls silently no-op when isEnabled is false', () async {
      AppHaptics.isEnabled = false;

      await AppHaptics.lightImpact();
      await AppHaptics.mediumImpact();
      await AppHaptics.heavyImpact();
      await AppHaptics.selectionClick();
      await AppHaptics.vibrate();

      expect(platformCalls, isEmpty);
    });
  });
}
