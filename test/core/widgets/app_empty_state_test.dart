import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/widgets/app_empty_state.dart';

void main() {
  testWidgets('AppEmptyState renders title, body, and CTA', (tester) async {
    bool primaryPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.tv_outlined,
            title: 'No Shows Yet',
            body: 'Add TV shows to get started.',
            primaryLabel: 'BROWSE SHOWS',
            onPrimary: () => primaryPressed = true,
          ),
        ),
      ),
    );

    expect(find.text('No Shows Yet'), findsOneWidget);
    expect(find.text('Add TV shows to get started.'), findsOneWidget);
    expect(find.text('BROWSE SHOWS'), findsOneWidget);

    await tester.tap(find.text('BROWSE SHOWS'));
    expect(primaryPressed, true);
  });

  testWidgets(
    'AppEmptyState content scrolls in short viewports so actions stay reachable',
    (tester) async {
      // Set a very short viewport (e.g. 200px height)
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool primaryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.tv_outlined,
              title: 'Very Long Title For An Empty State',
              body:
                  'This is a multi-line body text explaining the empty state in detail to test short viewport layout.',
              primaryLabel: 'REACHABLE CTA',
              onPrimary: () => primaryPressed = true,
            ),
          ),
        ),
      );

      // Verify no overflow error occurred during build
      expect(tester.takeException(), isNull);

      // Verify SingleChildScrollView exists
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Scroll to make sure CTA is reachable and tappable
      await tester.scrollUntilVisible(find.text('REACHABLE CTA'), 50.0);
      await tester.pumpAndSettle();

      await tester.tap(find.text('REACHABLE CTA'));
      expect(primaryPressed, true);
    },
  );
}
