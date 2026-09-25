import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/widgets/app_snackbar.dart';

void main() {
  group('AppSnackbar', () {
    testWidgets('renders message and action button, and triggers onAction callback on tap', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackbar.showWithAction(
                      context,
                      message: 'Removed "Inception" from watchlist',
                      actionLabel: 'UNDO',
                      onAction: () => actionTriggered = true,
                    );
                  },
                  child: const Text('Show SnackBar'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show SnackBar'));
      await tester.pump(); // Start entry animation
      await tester.pump(const Duration(milliseconds: 300)); // Complete entry

      expect(find.text('Removed "Inception" from watchlist'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('renders standard snackbar without action button when action is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackbar.showInfo(
                      context,
                      'Standard info message',
                    );
                  },
                  child: const Text('Show Info'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Info'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Standard info message'), findsOneWidget);
      expect(find.text('UNDO'), findsNothing);
    });
  });
}
