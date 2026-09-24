import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/app_haptics.dart';
import '../theme/app_colors.dart';

/// A rich, interactive circular check button featuring scale bounce, smooth
/// color morphing, haptic feedback sequencing, and a lightweight micro-particle
/// celebration burst for season finales and movie completions.
class AnimatedCheckButton extends StatefulWidget {
  final bool isWatched;
  final bool isLoading;
  final bool isFinale;
  final bool isMovie;
  final double size;
  final VoidCallback? onTap;
  final Color? activeColor;

  const AnimatedCheckButton({
    super.key,
    required this.isWatched,
    this.isLoading = false,
    this.isFinale = false,
    this.isMovie = false,
    this.size = 40.0,
    this.onTap,
    this.activeColor,
  });

  @override
  State<AnimatedCheckButton> createState() => _AnimatedCheckButtonState();
}

class _AnimatedCheckButtonState extends State<AnimatedCheckButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _checkController;
  late final Animation<double> _checkScaleAnimation;

  late final AnimationController _particleController;
  late final List<_Particle> _particles;

  Timer? _hapticTimer;

  static const List<Color> _celebrationPalette = [
    AppColors.primary,
    AppColors.success,
    Color(0xFFFFB800), // Gold
    Color(0xFFEC4899), // Pink
    Color(0xFF00E5FF), // Cyan
    Color(0xFF8B5CF6), // Violet
  ];

  @override
  void initState() {
    super.initState();

    // 1. Scale down bounce controller (pressed feel)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // 2. Check icon pop controller
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isWatched ? 1.0 : 0.0,
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );

    // 3. Celebratory micro-particle burst controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _particles = _generateParticles();
  }

  List<_Particle> _generateParticles() {
    final random = math.Random(42);
    const count = 16;
    return List.generate(count, (index) {
      final baseAngle = (index * 2 * math.pi) / count;
      final angleJitter = (random.nextDouble() - 0.5) * 0.35;
      final angle = baseAngle + angleJitter;
      final maxDistance = 24.0 + random.nextDouble() * 20.0;
      final size = 2.2 + random.nextDouble() * 2.2;
      final color = _celebrationPalette[index % _celebrationPalette.length];
      return _Particle(
        angle: angle,
        maxDistance: maxDistance,
        size: size,
        color: color,
      );
    });
  }

  @override
  void didUpdateWidget(AnimatedCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWatched != oldWidget.isWatched) {
      if (widget.isWatched) {
        _checkController.forward(from: 0.0);
        if (widget.isFinale || widget.isMovie) {
          _particleController.forward(from: 0.0);
        }
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _scaleController.dispose();
    _checkController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading || widget.onTap == null) return;

    if (!widget.isWatched) {
      // 1. Instant tactile feedback on touch
      unawaited(AppHaptics.lightImpact());

      // 2. Quick scale bounce
      _scaleController.forward().then((_) {
        if (mounted) _scaleController.reverse();
      });

      // 3. Trigger celebratory particle burst if finale or movie
      if (widget.isFinale || widget.isMovie) {
        _particleController.forward(from: 0.0);
        _hapticTimer?.cancel();
        _hapticTimer = Timer(const Duration(milliseconds: 140), () {
          if (mounted) {
            unawaited(AppHaptics.heavyImpact());
          }
        });
      } else {
        _hapticTimer?.cancel();
        _hapticTimer = Timer(const Duration(milliseconds: 140), () {
          if (mounted) {
            unawaited(AppHaptics.mediumImpact());
          }
        });
      }
    } else {
      // Unwatching / reverting
      unawaited(AppHaptics.selectionClick());
      _scaleController.forward().then((_) {
        if (mounted) _scaleController.reverse();
      });
    }

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final effectiveActiveColor = widget.activeColor ?? AppColors.success;

    final inactiveBg = isLight ? Colors.transparent : AppColors.surface;
    final inactiveBorder = isLight
        ? AppColors.lightTextTertiary
        : Colors.transparent;

    final checkColor = isLight
        ? (widget.isWatched
            ? AppColors.textOnPrimary
            : AppColors.lightTextTertiary)
        : (widget.isWatched
            ? AppColors.textOnPrimary
            : AppColors.textTertiary);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Celebratory micro-particle painter (bursts outside the circle)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  if (_particleController.isAnimating) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _MicroParticlePainter(
                        progress: _particleController.value,
                        particles: _particles,
                        isMovie: widget.isMovie,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 2. Animated Scaling Button
              ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isWatched ? effectiveActiveColor : inactiveBg,
                    border: widget.isWatched
                        ? null
                        : Border.all(color: inactiveBorder, width: 1.5),
                    boxShadow: widget.isWatched
                        ? [
                            BoxShadow(
                              color: effectiveActiveColor.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 8.0,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: widget.size * 0.5,
                            height: widget.size * 0.5,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.isWatched
                                    ? AppColors.textOnPrimary
                                    : (isLight
                                        ? AppColors.lightPrimary
                                        : AppColors.primary),
                              ),
                            ),
                          )
                        : ScaleTransition(
                            scale: widget.isWatched
                                ? _checkScaleAnimation
                                : const AlwaysStoppedAnimation(1.0),
                            child: Icon(
                              Icons.check_rounded,
                              size: widget.size * 0.6,
                              color: checkColor,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double maxDistance;
  final double size;
  final Color color;

  const _Particle({
    required this.angle,
    required this.maxDistance,
    required this.size,
    required this.color,
  });
}

class _MicroParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final bool isMovie;

  _MicroParticlePainter({
    required this.progress,
    required this.particles,
    required this.isMovie,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final distanceFactor = Curves.easeOutCubic.transform(progress);
    final opacity = (1.0 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);

    for (final particle in particles) {
      final distance = (size.width * 0.45) + (particle.maxDistance * distanceFactor);
      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final radius = particle.size * (1.0 - 0.45 * progress);

      if (isMovie && particle.angle.abs() % 2 < 1.0) {
        // Star sparkle particle for cinematic finish
        _drawSparkle(canvas, Offset(x, y), radius * 1.4, paint);
      } else {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MicroParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
