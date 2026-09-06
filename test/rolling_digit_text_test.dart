import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/widgets/rolling_digit_text.dart';

void main() {
  testWidgets('RollingDigitText renders initial digits statically when animateInitial is false', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 100,
            animateInitial: false,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Initial render displays '1', '0', '0'
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('RollingDigitText performs entrance ticker spin when animateInitial is true', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 110,
            animateInitial: true,
            maxInitialSteps: 6,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // On frame 0: starts at 110 - 6 = 104 ('1', '0', '4')
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // Advance through the ticker roll until completion
    await tester.pumpAndSettle();

    // After settling: '1', '1', '0'
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('RollingDigitText animates only changing digits on increment', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 100,
            animateInitial: false,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Initial state
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));

    // Update from 100 to 101
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 101,
            animateInitial: false,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Mid-animation frame: both old '0' and new '1' exist in the transition for the ones slot
    await tester.pump(const Duration(milliseconds: 100));

    // Complete animation
    await tester.pumpAndSettle();

    // After settling: '1', '0', '1'
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('RollingDigitText handles digit count change', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 9,
            animateInitial: false,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    expect(find.text('9'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 10,
            animateInitial: false,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('RollingDigitText triggers entrance roll when animationTrigger increments', (WidgetTester tester) async {
    // Initially on off-screen tab (trigger = 0, animateInitial = false)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 42,
            animationTrigger: 0,
            animateInitial: false,
            maxInitialSteps: 6,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Initial state: statically shows '4' and '2'
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // User navigates onto the screen -> animationTrigger becomes 1
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 42,
            animationTrigger: 1,
            animateInitial: true,
            maxInitialSteps: 6,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Entrance roll begins from 42 - 6 = 36 ('3', '6')
    expect(find.text('3'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // Settle through the rolling steps
    await tester.pumpAndSettle();

    // After settling: final '4', '2'
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('RollingDigitText triggers entrance roll when value transitions from 0 to positive count', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 0,
            animationTrigger: 1,
            animateInitial: true,
            maxInitialSteps: 6,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    // Data loads: count becomes 20
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RollingDigitText(
            value: 20,
            animationTrigger: 1,
            animateInitial: true,
            maxInitialSteps: 6,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    // Entrance roll begins from 20 - 6 = 14 ('1', '4')
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.pumpAndSettle();

    // After settling: final '2', '0'
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}

