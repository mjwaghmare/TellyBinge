import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/presentation/widgets/rolling_dice_button.dart';

void main() {
  group('RollingDiceButton', () {
    testWidgets('renders idle state and triggers onPressed on tap', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: false,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(RollingDiceButton), findsOneWidget);
      await tester.tap(find.byType(RollingDiceButton));
      expect(pressed, isTrue);
    });

    testWidgets('does not trigger onPressed while isRolling is true', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: true,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RollingDiceButton));
      expect(pressed, isFalse);
    });

    testWidgets('respects reduced motion by not repeating animation under reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RollingDiceButton(
                isRolling: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Under reduced motion, no infinite ticker repeat is started
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('resumes repeating when isRolling transitions back to true while completing a forward pass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Advance into roll
      await tester.pump(const Duration(milliseconds: 200));

      // Transition to isRolling = false (starts finishing forward pass)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: false,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Still finishing
      await tester.pump(const Duration(milliseconds: 100));

      // Transition back to isRolling = true before finishing pass finishes
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Let animation run further
      await tester.pump(const Duration(milliseconds: 500));
      // Ticker should still be actively scheduling frames because repetition resumed
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('does not start repeating when app lifecycle is not resumed', (tester) async {
      // Simulate inactive app lifecycle
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Restore to resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('resets controller when inactive transition interrupts final pass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Switch to isRolling = false to trigger finishing pass
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingDiceButton(
              isRolling: false,
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));

      // Interrupt while finishing
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // No frames should be scheduled and controller is stopped/reset
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Restore resumed state
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // Since isRolling is false, should not resume
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
