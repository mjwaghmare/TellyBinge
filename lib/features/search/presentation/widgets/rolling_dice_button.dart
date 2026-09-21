import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/services/app_haptics.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant RollingDiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling != oldWidget.isRolling) {
      if (widget.isRolling) {
        _controller.repeat();
      } else {
        _controller.forward().then((_) {
          if (mounted && !widget.isRolling) {
            _controller.value = 0; // Reset smoothly after finishing the loop
          }
        });
      }
    }
  }

  @override
  void dispose() {
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
                  if (widget.isRolling) {
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
