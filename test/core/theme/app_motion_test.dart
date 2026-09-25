import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/core/sync/sync_status_cubit.dart';
import 'package:popverse/core/sync/sync_status_state.dart';
import 'package:popverse/core/theme/app_motion.dart';
import 'package:popverse/core/widgets/animated_check_button.dart';
import 'package:popverse/core/widgets/offline_sync_banner.dart';
import 'package:popverse/features/profile/presentation/cubit/settings_cubit.dart';

class FakeTmdbClient implements TmdbClient {
  @override
  bool allowAdultContent = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSyncStatusCubit extends Cubit<SyncStatusState> implements SyncStatusCubit {
  FakeSyncStatusCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPageTransitionsBuilder extends PageTransitionsBuilder {
  final VoidCallback onBuild;
  const _TestPageTransitionsBuilder({required this.onBuild});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    onBuild();
    return child;
  }
}

Widget _wrapWithMediaQuery({
  required Widget child,
  bool disableAnimations = false,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AppMotion: Token and Rule Verification', () {
    test('Reduced motion duration tokens meet strict accessibility specifications', () {
      expect(AppMotion.instant, equals(Duration.zero));
      expect(AppMotion.reducedFade, lessThanOrEqualTo(const Duration(milliseconds: 120)));
      expect(AppMotion.reducedFade, equals(const Duration(milliseconds: 100)));
      expect(AppMotion.fast, equals(const Duration(milliseconds: 150)));
      expect(AppMotion.normal, equals(const Duration(milliseconds: 250)));
      expect(AppMotion.medium, equals(const Duration(milliseconds: 350)));
      expect(AppMotion.slow, equals(const Duration(milliseconds: 500)));
    });

    testWidgets('Resolves normal durations and curves when reduced motion is disabled', (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              expect(AppMotion.isReducedMotion(context), isFalse);
              expect(context.isReducedMotion, isFalse);

              expect(
                AppMotion.duration(context, AppMotion.normal),
                equals(AppMotion.normal),
              );
              expect(
                context.motionDuration(AppMotion.normal),
                equals(AppMotion.normal),
              );

              expect(
                AppMotion.fadeDuration(context),
                equals(AppMotion.normal),
              );
              expect(
                context.motionFade(),
                equals(AppMotion.normal),
              );

              expect(
                AppMotion.curve(context, AppMotion.bounce),
                equals(AppMotion.bounce),
              );
              expect(
                context.motionCurve(AppMotion.bounce),
                equals(AppMotion.bounce),
              );

              expect(
                AppMotion.value(context, 0.5),
                equals(0.5),
              );

              expect(
                AppMotion.offset(context, const Offset(0, -1.0)),
                equals(const Offset(0, -1.0)),
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('Drops durations to 0ms and clamps fades to <=120ms when reduced motion is enabled', (tester) async {
      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              expect(AppMotion.isReducedMotion(context), isTrue);
              expect(context.isReducedMotion, isTrue);

              // Spatial duration dropped to 0ms
              expect(
                AppMotion.duration(context, AppMotion.normal),
                equals(Duration.zero),
              );
              expect(
                context.motionDuration(AppMotion.normal),
                equals(Duration.zero),
              );

              // Fade duration clamped to reducedFade (<=120ms)
              expect(
                AppMotion.fadeDuration(context),
                equals(AppMotion.reducedFade),
              );
              expect(
                context.motionFade(),
                equals(AppMotion.reducedFade),
              );

              // Even if a caller requests 200ms reduced fade, it is clamped to 120ms
              expect(
                AppMotion.fadeDuration(
                  context,
                  reducedDuration: const Duration(milliseconds: 200),
                ),
                equals(const Duration(milliseconds: 120)),
              );

              // Curve falls back to linear
              expect(
                AppMotion.curve(context, AppMotion.bounce),
                equals(Curves.linear),
              );
              expect(
                context.motionCurve(AppMotion.bounce),
                equals(Curves.linear),
              );

              // Value clamped to reducedValue (1.0 default)
              expect(
                AppMotion.value(context, 0.5),
                equals(1.0),
              );

              // Offset clamped to Offset.zero
              expect(
                AppMotion.offset(context, const Offset(0, -1.0)),
                equals(Offset.zero),
              );

              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('ReducedMotionPageTransitionsBuilder', () {
    testWidgets('builds FadeTransition with compressed timeline (Interval 0.0 to 0.4) on Android when reduced motion is enabled', (tester) async {
      const builder = ReducedMotionPageTransitionsBuilder();
      late Widget transitionResult;

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          platform: TargetPlatform.android,
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              final route = MaterialPageRoute(builder: (_) => const SizedBox());
              final controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(milliseconds: 300),
              );
              transitionResult = builder.buildTransitions(
                route,
                context,
                controller,
                controller,
                const Text('Page Content'),
              );
              return transitionResult;
            },
          ),
        ),
      );

      expect(transitionResult, isA<FadeTransition>());
      final fade = transitionResult as FadeTransition;
      expect(fade.opacity, isA<CurvedAnimation>());
      final curved = fade.opacity as CurvedAnimation;
      expect(curved.curve, isA<Interval>());
      final interval = curved.curve as Interval;
      expect(interval.begin, equals(0.0));
      expect(interval.end, closeTo(0.4, 0.001));
    });

    testWidgets('delegates to defaultBuilder on iOS even when reduced motion is enabled to preserve edge-swipe back gesture', (tester) async {
      bool defaultBuilderCalled = false;
      final builder = ReducedMotionPageTransitionsBuilder(
        defaultBuilder: _TestPageTransitionsBuilder(
          onBuild: () => defaultBuilderCalled = true,
        ),
      );

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          platform: TargetPlatform.iOS,
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              final route = MaterialPageRoute(builder: (_) => const SizedBox());
              final controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(milliseconds: 300),
              );
              return builder.buildTransitions(
                route,
                context,
                controller,
                controller,
                const Text('Page Content'),
              );
            },
          ),
        ),
      );

      expect(defaultBuilderCalled, isTrue);
    });

    testWidgets('delegates to defaultBuilder on macOS even when reduced motion is enabled to preserve edge-swipe back gesture', (tester) async {
      bool defaultBuilderCalled = false;
      final builder = ReducedMotionPageTransitionsBuilder(
        defaultBuilder: _TestPageTransitionsBuilder(
          onBuild: () => defaultBuilderCalled = true,
        ),
      );

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          platform: TargetPlatform.macOS,
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              final route = MaterialPageRoute(builder: (_) => const SizedBox());
              final controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(milliseconds: 300),
              );
              return builder.buildTransitions(
                route,
                context,
                controller,
                controller,
                const Text('Page Content'),
              );
            },
          ),
        ),
      );

      expect(defaultBuilderCalled, isTrue);
    });

    testWidgets('delegates to defaultBuilder when reduced motion is disabled', (tester) async {
      bool defaultBuilderCalled = false;
      final builder = ReducedMotionPageTransitionsBuilder(
        defaultBuilder: _TestPageTransitionsBuilder(
          onBuild: () => defaultBuilderCalled = true,
        ),
      );

      await tester.pumpWidget(
        _wrapWithMediaQuery(
          disableAnimations: false,
          child: Builder(
            builder: (context) {
              final route = MaterialPageRoute(builder: (_) => const SizedBox());
              final controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(milliseconds: 100),
              );
              return builder.buildTransitions(
                route,
                context,
                controller,
                controller,
                const Text('Page Content'),
              );
            },
          ),
        ),
      );

      expect(defaultBuilderCalled, isTrue);
    });
  });

  group('SettingsCubit: Reduced Motion In-App Preference', () {
    late SharedPreferences prefs;
    late FakeTmdbClient fakeTmdbClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeTmdbClient = FakeTmdbClient();
    });

    test('initial state has reducedMotion = false when not set in prefs', () {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: fakeTmdbClient);
      expect(cubit.state.reducedMotion, isFalse);
    });

    test('loads reducedMotion = true when persisted in prefs', () async {
      await prefs.setBool(AppStorageKeys.reducedMotionEnabled, true);
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: fakeTmdbClient);
      expect(cubit.state.reducedMotion, isTrue);
    });

    test('toggleReducedMotion persists value to prefs and emits updated state', () async {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: fakeTmdbClient);
      expect(cubit.state.reducedMotion, isFalse);

      await cubit.toggleReducedMotion(true);
      expect(cubit.state.reducedMotion, isTrue);
      expect(prefs.getBool(AppStorageKeys.reducedMotionEnabled), isTrue);

      await cubit.toggleReducedMotion(false);
      expect(cubit.state.reducedMotion, isFalse);
      expect(prefs.getBool(AppStorageKeys.reducedMotionEnabled), isFalse);
    });
  });

  group('Widget Integration: OfflineSyncBanner under Reduced Motion', () {
    testWidgets('drops slide translation to 0ms and uses gentle fade when reduced motion is on', (tester) async {
      final cubit = FakeSyncStatusCubit(
        const SyncStatusState(
          hasPendingWrites: true,
          justSynced: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<SyncStatusCubit>.value(
              value: cubit,
              child: const Scaffold(
                body: OfflineSyncBanner(),
              ),
            ),
          ),
        ),
      );

      final slideFinder = find.byType(AnimatedSlide);
      expect(slideFinder, findsOneWidget);
      final animatedSlide = tester.widget<AnimatedSlide>(slideFinder);
      expect(animatedSlide.duration, equals(Duration.zero));
      expect(animatedSlide.offset, equals(Offset.zero));

      final opacityFinder = find.byType(AnimatedOpacity);
      expect(opacityFinder, findsOneWidget);
      final animatedOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(animatedOpacity.duration, lessThanOrEqualTo(const Duration(milliseconds: 120)));
    });
  });

  group('Widget Integration: AnimatedCheckButton under Reduced Motion', () {
    testWidgets('omits scale animation bounce and particle bursts under reduced motion', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AnimatedCheckButton(
                isWatched: false,
                isMovie: true,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify button rendered
      final checkFinder = find.byType(AnimatedCheckButton);
      expect(checkFinder, findsOneWidget);

      // Tap button
      await tester.tap(checkFinder);
      await tester.pump();

      expect(tapped, isTrue);

      // ScaleTransition must stay 1.0 (no bounce)
      final scaleTransitions = tester.widgetList<ScaleTransition>(
        find.descendant(of: checkFinder, matching: find.byType(ScaleTransition)),
      );
      for (final st in scaleTransitions) {
        expect(st.scale.value, equals(1.0));
      }

      // No celebratory micro-particle painter rendered
      final particleFinder = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter != null &&
            w.painter.runtimeType.toString() == '_MicroParticlePainter',
      );
      expect(particleFinder, findsNothing);
    });
  });
}
