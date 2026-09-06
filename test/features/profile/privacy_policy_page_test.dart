import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/presentation/pages/privacy_policy_page.dart';

void main() {
  testWidgets('PrivacyPolicyPage renders sections and pops on back button',
      (tester) async {
    bool popped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onDidRemovePage: (_) => popped = true,
          pages: const [
            MaterialPage(child: Scaffold(body: Text('Home'))),
            MaterialPage(child: PrivacyPolicyPage()),
          ],
        ),
      ),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('PopVerse Privacy Policy'), findsOneWidget);
    expect(find.text('Our Core Privacy Principles'), findsOneWidget);

    // Scroll until 'How We Use Your Information' is visible
    await tester.scrollUntilVisible(
      find.text('How We Use Your Information'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('How We Use Your Information'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });
}
