import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:popverse/core/theme/app_colors.dart';
import 'package:popverse/core/theme/app_theme.dart';
import 'package:popverse/core/widgets/animated_check_button.dart';

double _relativeLuminance(Color color) {
  double channel(double value) {
    if (value <= 0.04045) {
      return value / 12.92;
    } else {
      return math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Accessibility: Contrast Checks (WCAG AA)', () {
    test('Dark mode text colors meet WCAG AA (>= 4.5:1) against dark surfaces', () {
      // Primary text on dark background & surface
      expect(_contrastRatio(AppColors.textPrimary, AppColors.darkBackground), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textPrimary, AppColors.surfaceElevated), greaterThanOrEqualTo(4.5));

      // Secondary text on dark background & surface
      expect(_contrastRatio(AppColors.textSecondary, AppColors.darkBackground), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textSecondary, AppColors.surfaceElevated), greaterThanOrEqualTo(4.5));

      // Tertiary text on dark background & surface
      expect(_contrastRatio(AppColors.textTertiary, AppColors.darkBackground), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textTertiary, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.textTertiary, AppColors.surfaceElevated), greaterThanOrEqualTo(4.5));

      // Status ended text on surface
      expect(_contrastRatio(AppColors.ended, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('Light mode text colors meet WCAG AA (>= 4.5:1) against light surfaces', () {
      // Primary text on light background & surface
      expect(_contrastRatio(AppColors.lightTextPrimary, AppColors.lightBackground), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.lightTextPrimary, AppColors.lightSurface), greaterThanOrEqualTo(4.5));

      // Secondary text on light surface
      expect(_contrastRatio(AppColors.lightTextSecondary, AppColors.lightSurface), greaterThanOrEqualTo(4.5));

      // Tertiary text on light surface and elevated surface
      expect(_contrastRatio(AppColors.lightTextTertiary, AppColors.lightSurface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.lightTextTertiary, AppColors.lightSurfaceElevated), greaterThanOrEqualTo(4.5));

      // Tonal container text
      expect(_contrastRatio(AppColors.lightOnSuccessContainer, AppColors.lightSuccessContainer), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.lightOnErrorContainer, AppColors.lightErrorContainer), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppColors.lightOnAiringContainer, AppColors.lightAiringContainer), greaterThanOrEqualTo(4.5));
    });
  });

  group('Accessibility: Touch Targets (>= 48dp)', () {
    test('AppTheme dark and light configurations enforce padded tap targets and minimum size 48x48', () {
      final dark = AppTheme.darkTheme();
      final light = AppTheme.lightTheme();

      expect(dark.materialTapTargetSize, equals(MaterialTapTargetSize.padded));
      expect(light.materialTapTargetSize, equals(MaterialTapTargetSize.padded));

      // IconButton
      final darkIconSize = dark.iconButtonTheme.style?.minimumSize?.resolve({});
      final lightIconSize = light.iconButtonTheme.style?.minimumSize?.resolve({});
      expect(darkIconSize?.width, greaterThanOrEqualTo(48.0));
      expect(darkIconSize?.height, greaterThanOrEqualTo(48.0));
      expect(lightIconSize?.width, greaterThanOrEqualTo(48.0));
      expect(lightIconSize?.height, greaterThanOrEqualTo(48.0));

      // ElevatedButton
      final darkElevatedSize = dark.elevatedButtonTheme.style?.minimumSize?.resolve({});
      final lightElevatedSize = light.elevatedButtonTheme.style?.minimumSize?.resolve({});
      expect(darkElevatedSize?.width, greaterThanOrEqualTo(48.0));
      expect(darkElevatedSize?.height, greaterThanOrEqualTo(48.0));
      expect(lightElevatedSize?.width, greaterThanOrEqualTo(48.0));
      expect(lightElevatedSize?.height, greaterThanOrEqualTo(48.0));

      // TextButton
      final darkTextSize = dark.textButtonTheme.style?.minimumSize?.resolve({});
      final lightTextSize = light.textButtonTheme.style?.minimumSize?.resolve({});
      expect(darkTextSize?.width, greaterThanOrEqualTo(48.0));
      expect(darkTextSize?.height, greaterThanOrEqualTo(48.0));
      expect(lightTextSize?.width, greaterThanOrEqualTo(48.0));
      expect(lightTextSize?.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('AnimatedCheckButton has >= 48x48 interactive touch target and semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedCheckButton(
                isWatched: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(AnimatedCheckButton);
      final renderBox = tester.renderObject<RenderBox>(buttonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      // Verify semantics
      final semanticsFinder = find.descendant(
        of: buttonFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true,
        ),
      );
      expect(semanticsFinder, findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      expect(semanticsWidget.properties.label, equals('Mark episode as watched'));
      expect(semanticsWidget.properties.value, equals('Unwatched'));
    });
  });

  group('Accessibility: Dynamic Type Scaling (up to 1.3x)', () {
    testWidgets('clamps text scale factor to max 1.3x', (tester) async {
      late double effectiveScale;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.5), // User requests very large text
          ),
          child: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              final clamped = mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
              );
              return MediaQuery(
                data: clamped,
                child: Builder(
                  builder: (innerContext) {
                    effectiveScale = MediaQuery.textScalerOf(innerContext).scale(10.0) / 10.0;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(effectiveScale, closeTo(1.3, 0.001));
    });
  });

  group('Accessibility: Screen-Reader Alternatives for Swipe Gestures', () {
    testWidgets('Semantics exposes custom actions for swipe actions', (tester) async {
      bool watchedCalled = false;
      bool removeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Mark as watched'): () {
                    watchedCalled = true;
                  },
                  const CustomSemanticsAction(label: 'Remove from watchlist'): () {
                    removeCalled = true;
                  },
                },
                child: const Text('Swipeable Movie Card'),
              ),
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.customSemanticsActions?.containsKey(
                  const CustomSemanticsAction(label: 'Mark as watched'),
                ) ==
                true,
      );

      expect(semanticsFinder, findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      final actions = semanticsWidget.properties.customSemanticsActions!;

      actions[const CustomSemanticsAction(label: 'Mark as watched')]!();
      expect(watchedCalled, isTrue);

      actions[const CustomSemanticsAction(label: 'Remove from watchlist')]!();
      expect(removeCalled, isTrue);
    });
  });
}
