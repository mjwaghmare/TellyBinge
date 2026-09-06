import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/presentation/pages/terms_and_conditions_page.dart';

void main() {
  testWidgets('TermsAndConditionsPage renders sections and pops on back button',
      (tester) async {
    bool popped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onDidRemovePage: (_) => popped = true,
          pages: const [
            MaterialPage(child: Scaffold(body: Text('Home'))),
            MaterialPage(child: TermsAndConditionsPage()),
          ],
        ),
      ),
    );

    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('PopVerse Terms of Service'), findsOneWidget);
    expect(find.text('No-Streaming & Information Utility Notice'), findsOneWidget);

    // Scroll until 'Nature of Service' is visible
    await tester.scrollUntilVisible(
      find.text('Nature of Service'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Nature of Service'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });
}
