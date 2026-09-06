import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sleek odometer-style rolling digit text widget.
///
/// When the value changes (e.g. from 100 to 101), stationary digits remain still,
/// while changing digits smoothly roll vertically (outgoing digit slides up and
/// out, incoming digit rolls in from the bottom for increments; reversed for decrements).
///
/// If [animateInitial] is true, upon mounting it performs a rapid ticker roll
/// through the last few numbers (e.g. 104 -> 106 -> ... -> 110) decelerating into
/// the final count, creating a tactile mechanical counter entrance.
class RollingDigitText extends StatefulWidget {
  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final bool animateInitial;
  final int maxInitialSteps;
  final Object? animationTrigger;

  const RollingDigitText({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.animateInitial = true,
    this.maxInitialSteps = 10,
    this.animationTrigger,
  });

  @override
  State<RollingDigitText> createState() => _RollingDigitTextState();
}

class _RollingDigitTextState extends State<RollingDigitText> {
  late int _displayValue;
  late int _previousDisplayValue;
  Duration? _stepDurationOverride;
  final List<Timer> _activeTimers = [];

  bool get _isTriggerActive {
    if (widget.animationTrigger == null) return widget.animateInitial;
    if (widget.animationTrigger is num) {
      return (widget.animationTrigger as num) > 0;
    }
    if (widget.animationTrigger is bool) {
      return widget.animationTrigger as bool;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.animateInitial && _isTriggerActive && widget.value > 0) {
      final steps = math.min(widget.value, widget.maxInitialSteps);
      final startVal = widget.value - steps;
      _displayValue = startVal;
      _previousDisplayValue = startVal;
      _scheduleEntranceSpin(startVal, widget.value, steps);
    } else {
      _displayValue = widget.value;
      _previousDisplayValue = widget.value;
    }
  }

  void _cancelTimers() {
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  void _startEntranceAnimation(int targetValue) {
    _cancelTimers();
    if (targetValue <= 0) {
      setState(() {
        _stepDurationOverride = null;
        _previousDisplayValue = 0;
        _displayValue = 0;
      });
      return;
    }
    final steps = math.min(targetValue, widget.maxInitialSteps);
    final startVal = targetValue - steps;
    setState(() {
      _stepDurationOverride = null;
      _previousDisplayValue = startVal;
      _displayValue = startVal;
    });
    _scheduleEntranceSpin(startVal, targetValue, steps);
  }

  void _scheduleEntranceSpin(int start, int end, int steps) {
    if (steps <= 0) return;

    // Smooth decelerating step intervals (natural mechanical counter deceleration)
    // Scales dynamically across steps (e.g. for 10 steps: ~50ms to 150ms, ~920ms total)
    final intervals = <int>[];
    const baseMs = 50.0;
    const maxMs = 150.0;
    for (int i = 0; i < steps; i++) {
      final progress = steps == 1 ? 1.0 : i / (steps - 1);
      final interval =
          (baseMs + (maxMs - baseMs) * math.pow(progress, 1.5)).round();
      intervals.add(interval);
    }

    int cumulativeDelay = 0;
    for (int i = 0; i < steps; i++) {
      final targetStepVal = start + i + 1;
      final stepDurationMs = intervals[i];
      cumulativeDelay += stepDurationMs;

      final timer = Timer(Duration(milliseconds: cumulativeDelay), () {
        if (!mounted) return;
        setState(() {
          _stepDurationOverride =
              Duration(milliseconds: (stepDurationMs * 0.98).round());
          _previousDisplayValue = _displayValue;
          _displayValue = targetStepVal;
        });

        // Clear step duration override after final step settles smoothly
        if (targetStepVal == end) {
          final settleTimer =
              Timer(Duration(milliseconds: stepDurationMs + 40), () {
            if (!mounted) return;
            setState(() {
              _stepDurationOverride = null;
            });
          });
          _activeTimers.add(settleTimer);
        }
      });
      _activeTimers.add(timer);
    }
  }

  @override
  void didUpdateWidget(covariant RollingDigitText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final triggerChanged =
        widget.animationTrigger != oldWidget.animationTrigger &&
        _isTriggerActive;
    final initialBecameActive =
        !oldWidget.animateInitial && widget.animateInitial && _isTriggerActive;
    final valueLoaded =
        oldWidget.value == 0 && widget.value > 0 && _isTriggerActive;

    if (triggerChanged || initialBecameActive || valueLoaded) {
      if (widget.value > 0) {
        _startEntranceAnimation(widget.value);
      } else {
        _cancelTimers();
        setState(() {
          _stepDurationOverride = null;
          _previousDisplayValue = 0;
          _displayValue = 0;
        });
      }
    } else if (oldWidget.value != widget.value) {
      _cancelTimers();
      setState(() {
        _stepDurationOverride = null;
        _previousDisplayValue = _displayValue;
        _displayValue = widget.value;
      });
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncrement = _displayValue >= _previousDisplayValue;
    final digits = _displayValue.toString().split('');
    final totalDigits = digits.length;
    final effectiveDuration = _stepDurationOverride ?? widget.duration;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: List.generate(totalDigits, (index) {
        // Place value from the right (0 = ones place, 1 = tens place, etc.)
        final posFromRight = totalDigits - 1 - index;
        final char = digits[index];
        final currentKey = ValueKey<String>('$posFromRight-$char');

        return ClipRect(
          child: AnimatedSwitcher(
            duration: effectiveDuration,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  ...previousChildren,
                  ?currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final isCurrent = child.key == currentKey;
              final curved = CurvedAnimation(
                parent: animation,
                curve: widget.curve,
              );

              // When incrementing (e.g. 100 -> 101):
              // - Incoming digit rolls up from bottom: (0, 0.75) -> (0, 0)
              // - Outgoing digit rolls up and out: (0, 0) -> (0, -0.75)
              // When decrementing:
              // - Incoming digit rolls down from top: (0, -0.75) -> (0, 0)
              // - Outgoing digit rolls down and out: (0, 0) -> (0, 0.75)
              final Offset inBegin = isIncrement
                  ? const Offset(0.0, 0.75)
                  : const Offset(0.0, -0.75);
              final Offset outEnd = isIncrement
                  ? const Offset(0.0, -0.75)
                  : const Offset(0.0, 0.75);

              final tween = isCurrent
                  ? Tween<Offset>(begin: inBegin, end: Offset.zero)
                  : Tween<Offset>(begin: outEnd, end: Offset.zero);

              return SlideTransition(
                position: tween.animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: child,
                ),
              );
            },
            child: Text(
              char,
              key: currentKey,
              style: widget.style,
            ),
          ),
        );
      }),
    );
  }
}
