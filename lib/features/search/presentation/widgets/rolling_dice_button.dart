import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';

class RollingDiceButton extends StatefulWidget {
  final bool isRolling;
  final VoidCallback onPressed;

  const RollingDiceButton({
    super.key,
    required this.isRolling,
    required this.onPressed,
  });

  @override
  State<RollingDiceButton> createState() => _RollingDiceButtonState();
}

class _RollingDiceButtonState extends State<RollingDiceButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  bool _isRepeating = false;
  bool _isFinishing = false;

  bool get _isAppResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant RollingDiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling != oldWidget.isRolling) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final isReduced = AppMotion.isReducedMotion(context);
    if (widget.isRolling) {
      if (isReduced) {
        _isRepeating = false;
        _isFinishing = false;
        if (_controller.isAnimating) {
          _controller.stop();
        }
        _controller.value = 0;
      } else {
        if ((!_isRepeating || _isFinishing || !_controller.isAnimating) &&
            _isAppResumed) {
          _isRepeating = true;
          _isFinishing = false;
          _controller.repeat();
        }
      }
    } else {
      _isRepeating = false;
      if (_controller.isAnimating) {
        _isFinishing = true;
        _controller.forward().then((_) {
          _isFinishing = false;
          if (mounted && !widget.isRolling) {
            _controller.value = 0;
          }
        });
      } else {
        _isFinishing = false;
        _controller.value = 0;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      if (_controller.isAnimating) {
        _controller.stop();
        if (!widget.isRolling) {
          _isFinishing = false;
          _controller.value = 0;
        }
      }
      _isRepeating = false;
    } else if (widget.isRolling &&
        mounted &&
        !AppMotion.isReducedMotion(context)) {
      _isRepeating = true;
      _isFinishing = false;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl, right: AppSpacing.xxs),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!widget.isRolling) {
            AppHaptics.heavyImpact();
            widget.onPressed();
          }
        },
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: Transform.scale(
              scale: 1.5,
              child: Lottie.asset(
                AppAssets.diceLottie,
                controller: _controller,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  if (widget.isRolling &&
                      !AppMotion.isReducedMotion(context) &&
                      _isAppResumed &&
                      (!_isRepeating || _isFinishing || !_controller.isAnimating)) {
                    _isRepeating = true;
                    _isFinishing = false;
                    _controller.repeat();
                  }
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.casino,
                    size: 34,
                    color:
                        Theme.of(context).iconTheme.color ?? AppColors.primary,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
