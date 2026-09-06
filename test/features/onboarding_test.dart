import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/constants/app_constants.dart';
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
    expect(find.text(AppConstants.onboardingSlide1Badge.toUpperCase()), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide1Title), findsOneWidget);
    expect(find.text(AppConstants.onboardingNextButton), findsOneWidget);
    expect(find.text(AppConstants.onboardingSkipButton), findsOneWidget);

    // Tap Next -> Slide 2 (Releases)
    await tester.tap(find.text(AppConstants.onboardingNextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ReleasesSlide), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide2Badge.toUpperCase()), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide2Title), findsOneWidget);

    // Tap Next -> Slide 3 (Surprise Me)
    await tester.tap(find.text(AppConstants.onboardingNextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DiscoverSlide), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide3Badge.toUpperCase()), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide3Title), findsOneWidget);

    // Tap Next -> Slide 4 (Stats)
    await tester.tap(find.text(AppConstants.onboardingNextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StatsSlide), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide4Badge.toUpperCase()), findsOneWidget);
    expect(find.text(AppConstants.onboardingSlide4Title), findsOneWidget);
    expect(find.text(AppConstants.onboardingStartButton), findsOneWidget);

    final skipVisibility = tester.widget<Visibility>(
      find.ancestor(
        of: find.text(AppConstants.onboardingSkipButton),
        matching: find.byType(Visibility),
      ),
    );
    expect(skipVisibility.visible, isFalse);

    // Tap 'Start tracking'
    await tester.tap(find.text(AppConstants.onboardingStartButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(finished, isTrue);
  });
}
