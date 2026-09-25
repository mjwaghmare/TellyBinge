import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Centralized motion and animation tokens for PopVerse.
///
/// Respects accessibility guidelines by automatically disabling or reducing
/// motion when the user requests reduced motion via system settings or
/// the in-app appearance preference.
///
/// Motion rules under reduced motion:
/// - Spatial movement (translations, scale bounce, 3D tilts, spins): 0ms (instant).
/// - Visual transitions (opacity/fades): ≤120ms (defaults to [reducedFade] = 100ms).
/// - Particle bursts / confetti: suppressed entirely.
class AppMotion {
  AppMotion._();

  // --- Duration Tokens ---

  /// 0ms instant transition. Used to immediately finish animations under reduced motion.
  static const Duration instant = Duration.zero;

  /// 100ms duration for micro-interactions and quick state feedback.
  static const Duration micro = Duration(milliseconds: 100);

  /// 150ms duration for fast transitions like icon toggles or chip selections.
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms duration for standard component transitions like modal sheets and cards.
  static const Duration normal = Duration(milliseconds: 250);

  /// 350ms duration for large surface morphs and banner slides.
  static const Duration medium = Duration(milliseconds: 350);

  /// 500ms duration for complex multi-stage choreographies.
  static const Duration slow = Duration(milliseconds: 500);

  /// Maximum allowed duration (100ms <= 120ms) for subtle opacity fades when
  /// reduced motion is enabled.
  static const Duration reducedFade = Duration(milliseconds: 100);

  // --- Curve Tokens ---

  /// Standard cubic curve for natural UI state transitions.
  static const Curve standard = Curves.easeInOutCubic;

  /// Emphasized deceleration curve for elements entering the screen.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Deceleration curve for quick dismissals or responsive touches.
  static const Curve decelerate = Curves.easeOutQuad;

  /// Acceleration curve for exits.
  static const Curve accelerate = Curves.easeInQuad;

  /// Playful spring/bounce curve (used only when reduced motion is disabled).
  static const Curve bounce = Curves.elasticOut;

  /// Flat linear curve for zero-overshoot or reduced motion transitions.
  static const Curve linear = Curves.linear;

  // --- Accessibility Resolvers ---

  /// Returns true if reduced motion is requested either via system settings
  /// (e.g. iOS 'Reduce Motion' / Android 'Remove animations') or the in-app
  /// accessibility toggle.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Resolves the animation duration according to reduced motion settings.
  /// If reduced motion is active, returns [reducedDuration] (defaults to [instant] = 0ms).
  static Duration duration(
    BuildContext context,
    Duration normalDuration, {
    Duration reducedDuration = instant,
  }) {
    return isReducedMotion(context) ? reducedDuration : normalDuration;
  }

  /// Resolves a fade duration, strictly ensuring it does not exceed the
  /// 120ms reduced-motion ceiling when reduced motion is active.
  static Duration fadeDuration(
    BuildContext context, {
    Duration normalDuration = normal,
    Duration reducedDuration = reducedFade,
  }) {
    if (!isReducedMotion(context)) return normalDuration;
    return reducedDuration > const Duration(milliseconds: 120)
        ? const Duration(milliseconds: 120)
        : reducedDuration;
  }

  /// Resolves animation curve according to reduced motion settings.
  static Curve curve(
    BuildContext context,
    Curve normalCurve, {
    Curve reducedCurve = linear,
  }) {
    return isReducedMotion(context) ? reducedCurve : normalCurve;
  }

  /// Resolves a scalar value (e.g., scale factor or progress), clamping to
  /// [reducedValue] (default 1.0) when reduced motion is active.
  static double value(
    BuildContext context,
    double normalValue, {
    double reducedValue = 1.0,
  }) {
    return isReducedMotion(context) ? reducedValue : normalValue;
  }

  /// Resolves a 2D offset (e.g. for slide transitions), clamping to
  /// [reducedOffset] (default [Offset.zero]) when reduced motion is active.
  static Offset offset(
    BuildContext context,
    Offset normalOffset, {
    Offset reducedOffset = Offset.zero,
  }) {
    return isReducedMotion(context) ? reducedOffset : normalOffset;
  }
}

/// Convenience BuildContext extension for ergonomic access to motion tokens.
extension AppMotionExtension on BuildContext {
  /// Whether reduced motion is active in the current context.
  bool get isReducedMotion => AppMotion.isReducedMotion(this);

  /// Resolves an animation duration for this context.
  Duration motionDuration(
    Duration normalDuration, {
    Duration reducedDuration = AppMotion.instant,
  }) =>
      AppMotion.duration(
        this,
        normalDuration,
        reducedDuration: reducedDuration,
      );

  /// Resolves a fade duration for this context (≤120ms if reduced motion).
  Duration motionFade({
    Duration normalDuration = AppMotion.normal,
    Duration reducedDuration = AppMotion.reducedFade,
  }) =>
      AppMotion.fadeDuration(
        this,
        normalDuration: normalDuration,
        reducedDuration: reducedDuration,
      );

  /// Resolves an animation curve for this context.
  Curve motionCurve(
    Curve normalCurve, {
    Curve reducedCurve = AppMotion.linear,
  }) =>
      AppMotion.curve(
        this,
        normalCurve,
        reducedCurve: reducedCurve,
      );
}

/// Page transitions builder that provides an instantaneous or gentle fade
/// when reduced motion is enabled, while maintaining standard iOS/Material
/// swipe-to-back transitions otherwise.
class ReducedMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  final PageTransitionsBuilder? defaultBuilder;

  const ReducedMotionPageTransitionsBuilder({
    this.defaultBuilder,
  });

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final builder = defaultBuilder ?? const CupertinoPageTransitionsBuilder();

    if (AppMotion.isReducedMotion(context)) {
      final platform = Theme.of(context).platform;
      final isApple =
          platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
      if (!isApple) {
        int totalDurationMs;
        try {
          totalDurationMs = route.transitionDuration.inMilliseconds;
        } catch (_) {
          totalDurationMs = 300;
        }
        final endFraction = totalDurationMs > 0
            ? (120 / totalDurationMs).clamp(0.0, 1.0)
            : 120 / 300;
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(0.0, endFraction, curve: Curves.linear),
        );
        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      }
    }

    return builder.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
