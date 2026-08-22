import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popverse/features/profile/presentation/widgets/profile_expiration_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProfileExpirationCard renders title and countdown units',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileExpirationCard(),
        ),
      ),
    );

    // Initial loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let futures resolve and timer run
    await tester.pumpAndSettle();

    // Check title and labels
    expect(find.text('Profile Expiration'), findsOneWidget);
    expect(find.text('DAYS'), findsOneWidget);
    expect(find.text('HOURS'), findsOneWidget);
    expect(find.text('MINS'), findsOneWidget);
    expect(find.text('SECS'), findsOneWidget);
  });
}
