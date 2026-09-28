import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/presentation/widgets/explore_language_filter_button.dart';

void main() {
  group('ExploreLanguageFilterButton', () {
    testWidgets('renders unfiltered All state by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreLanguageFilterButton(
              selectedLanguage: null,
              onLanguageChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
    });

    testWidgets('renders filtered state with flag and code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreLanguageFilterButton(
              selectedLanguage: 'ja',
              onLanguageChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('🇯🇵'), findsOneWidget);
      expect(find.text('JA'), findsOneWidget);
      expect(find.text('All'), findsNothing);
    });

    testWidgets('tapping button opens action sheet and selecting language fires callback', (
      tester,
    ) async {
      String? changed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExploreLanguageFilterButton(
                  selectedLanguage: changed,
                  onLanguageChanged: (val) => setState(() => changed = val),
                );
              },
            ),
          ),
        ),
      );

      // Tap on the pill button
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Verify sheet title
      expect(find.text('Filter by Language'), findsOneWidget);

      // Verify languages are listed
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Marathi'), findsOneWidget);
      expect(find.text('Japanese'), findsOneWidget);

      // Tap Hindi
      await tester.tap(find.text('Hindi'));
      await tester.pumpAndSettle();

      // Callback received 'hi'
      expect(changed, 'hi');
      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('HI'), findsOneWidget);
    });

    testWidgets('selecting All fires callback with null', (tester) async {
      String? changed = 'hi';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ExploreLanguageFilterButton(
                  selectedLanguage: changed,
                  onLanguageChanged: (val) => setState(() => changed = val),
                );
              },
            ),
          ),
        ),
      );

      // Initial state is Hindi
      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('HI'), findsOneWidget);

      // Tap to open sheet
      await tester.tap(find.text('HI'));
      await tester.pumpAndSettle();

      // Tap All
      await tester.tap(find.text('Every available language'));
      await tester.pumpAndSettle();

      expect(changed, isNull);
      expect(find.text('All'), findsOneWidget);
    });
  });
}
