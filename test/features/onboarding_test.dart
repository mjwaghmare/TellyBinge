import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popverse/core/constants/app_constants.dart';
import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/features/onboarding/data/onboarding_storage.dart';
import 'package:popverse/features/onboarding/presentation/pages/onboarding_gate.dart';
import 'package:popverse/features/onboarding/presentation/pages/onboarding_matching_page.dart';
import 'package:popverse/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:popverse/features/onboarding/presentation/widgets/onboarding_slides.dart';
import 'package:popverse/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late TmdbClient tmdbClient;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmdbClient = TmdbClient();
  });

  Widget buildTestApp(Widget child) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>.value(value: prefs),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>(
            create: (_) => SettingsCubit(prefs: prefs, tmdbClient: tmdbClient),
          ),
        ],
        child: MaterialApp(
          home: child,
        ),
      ),
    );
  }

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

  testWidgets(
      'OnboardingMatchingPage renders 12 overlapping posters, genre selection, and completes on Continue tap',
      (tester) async {
    bool finished = false;

    await tester.pumpWidget(
      buildTestApp(
        OnboardingMatchingPage(
          onFinished: () {
            finished = true;
          },
        ),
      ),
    );
    await tester.pump();

    // Verify Title & Subtitle presence
    expect(find.text('What do you love to watch?'), findsOneWidget);
    expect(find.textContaining('genres selected'), findsOneWidget);

    // Verify exactly 12 posters are rendered
    expect(find.byType(Image), findsNWidgets(12));

    // Verify Continue button is present
    final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
    expect(continueButton, findsOneWidget);

    // Tap Continue button
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    final storage = OnboardingStorage(prefs);
    expect(storage.preferredGenres, isNotEmpty);
    expect(prefs.getBool(AppStorageKeys.pendingOnboardingGenresSync), isTrue);
  });

  testWidgets(
      'OnboardingMatchingPage completes on X close button tap',
      (tester) async {
    bool finished = false;

    await tester.pumpWidget(
      buildTestApp(
        OnboardingMatchingPage(
          onFinished: () {
            finished = true;
          },
        ),
      ),
    );
    await tester.pump();

    final closeButtonFinder = find.byIcon(Icons.close_rounded);
    expect(closeButtonFinder, findsOneWidget);
    await tester.tap(closeButtonFinder);
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('OnboardingGate transitions from carousel to matching screen',
      (tester) async {
    await tester.pumpWidget(
      buildTestApp(const OnboardingGate()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially shows OnboardingPage
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(OnboardingMatchingPage), findsNothing);

    // Tap Skip on intro carousel
    await tester.tap(find.text(AppConstants.onboardingSkipButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Now transitions to OnboardingMatchingPage
    expect(find.byType(OnboardingMatchingPage), findsOneWidget);
    expect(find.text('What do you love to watch?'), findsOneWidget);
  });
}

