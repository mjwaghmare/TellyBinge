import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:popverse/features/onboarding/presentation/widgets/onboarding_slides.dart';

void main() {
  testWidgets('OnboardingPage displays 4 slides and completes on finish',
      (tester) async {
    bool finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          onFinished: () {
            finished = true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initial slide: Tracking
    expect(find.byType(TrackingSlide), findsOneWidget);
    expect(find.text('TRACKING'), findsOneWidget);
    expect(find.text('Track your shows and movies in one place'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Tap Next -> Slide 2 (Releases)
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReleasesSlide), findsOneWidget);
    expect(find.text('RELEASES'), findsOneWidget);
    expect(find.text('Never miss a premiere or finale'), findsOneWidget);

    // Tap Next -> Slide 3 (Surprise Me)
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DiscoverSlide), findsOneWidget);
    expect(find.text('SURPRISE ME'), findsOneWidget);
    expect(find.text('Can’t decide? Roll the dice'), findsOneWidget);

    // Tap Next -> Slide 4 (Stats)
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StatsSlide), findsOneWidget);
    expect(find.text('YOUR STATS'), findsOneWidget);
    expect(find.text('Your watch habits, beautifully visualized'), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);

    final skipVisibility = tester.widget<Visibility>(
      find.ancestor(
        of: find.text('Skip'),
        matching: find.byType(Visibility),
      ),
    );
    expect(skipVisibility.visible, isFalse);

    // Tap 'Start tracking'
    await tester.tap(find.text('Start tracking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(finished, isTrue);
  });
}
