import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/app_haptics.dart';
import '../services/share_card_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'polaroid_share_card.dart';

/// Full-screen modal presentation of the [PolaroidShareCard]
/// with 3D gyroscope motion, full-bleed colored blurred ambient background,
/// frosted-glass controls, and choreographed entrance bounce animation.
class PolaroidShareModal extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final double? rating;
  final DateTime? watchedDate;
  final String? mediaType;

  const PolaroidShareModal({
    super.key,
    required this.title,
    this.imageUrl,
    this.rating,
    this.watchedDate,
    this.mediaType,
  });

  /// Convenient helper to display the modal screen sliding up from the bottom.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? imageUrl,
    double? rating,
    DateTime? watchedDate,
    String? mediaType,
  }) async {
    await AppHaptics.mediumImpact();
    if (!context.mounted) return;
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => PolaroidShareModal(
          title: title,
          imageUrl: imageUrl,
          rating: rating,
          watchedDate: watchedDate,
          mediaType: mediaType,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curvedAnimation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<PolaroidShareModal> createState() => _PolaroidShareModalState();
}

class _PolaroidShareModalState extends State<PolaroidShareModal>
    with TickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late bool _showRating;
  final bool _showDate = true;
  double? _currentRating;
  bool _isSharing = false;
  bool _isExporting = false;

  // 3D Motion Sensors & Dynamic Calibration (Purely device-driven)
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  late final Ticker _tiltTicker;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _targetTiltX = 0.0;
  double _targetTiltY = 0.0;
  double? _baseX;
  double? _baseY;

  // 4-side haptic edge triggers
  bool _hapticLeftArmed = true;
  bool _hapticRightArmed = true;
  bool _hapticTopArmed = true;
  bool _hapticBottomArmed = true;

  // Share button anchor key & precache tracking
  final GlobalKey _shareButtonKey = GlobalKey();
  Future<void>? _precacheFuture;
  bool _isImagePrecached = false;

  // Choreographed Entrance Animations
  late final AnimationController _entranceController;
  late final Animation<Offset> _cardSlideAnimation;
  late final Animation<double> _cardScaleAnimation;
  late final Animation<double> _cardFadeAnimation;
  late final Animation<Offset> _controlsSlideAnimation;
  late final Animation<double> _controlsFadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
    _showRating = true;

    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    _isImagePrecached = !hasImage;

    // 1. Setup Staggered Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Card bounces up from bottom with spring overshoot
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _cardScaleAnimation = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Controls smoothly slide and fade in afterwards
    _controlsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controlsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    // 2. Pre-cache image so RepaintBoundary captures without delay
    if (hasImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final future = precacheImage(
            CachedNetworkImageProvider(widget.imageUrl!),
            context,
          );
          _precacheFuture = future;
          future.then((_) {
            if (mounted) {
              setState(() => _isImagePrecached = true);
            }
          }).catchError((_) {
            if (mounted) {
              setState(() => _isImagePrecached = true);
            }
          });
        }
      });
    }

    // 3. Smooth Display-Synchronized Ticker (interpolates device tilt at 60/120Hz)
    _tiltTicker = createTicker((_) {
      if (!mounted || _isExporting) return;

      final targetX = _targetTiltX.clamp(-0.06, 0.06);
      final targetY = _targetTiltY.clamp(-0.06, 0.06);

      final newX = ui.lerpDouble(_tiltX, targetX, 0.14) ?? targetX;
      final newY = ui.lerpDouble(_tiltY, targetY, 0.14) ?? targetY;

      if ((newX - _tiltX).abs() > 0.0004 || (newY - _tiltY).abs() > 0.0004) {
        setState(() {
          _tiltX = newX;
          _tiltY = newY;
        });
        _checkEdgeHaptics(newX, newY);
      }
    });
    _tiltTicker.start();

    // 4. Initialize Accelerometer listener with dynamic resting calibration
    try {
      _sensorSubscription = accelerometerEventStream().listen((event) {
        if (!mounted || _isExporting) return;

        // Establish initial baseline on device holding angle (handles iOS portrait coordinates)
        if (_baseX == null) {
          _baseX = event.x;
          _baseY = event.y;
        } else {
          // Slow adaptive drift compensation to allow natural posture adjustment
          _baseX = _baseX! * 0.994 + event.x * 0.006;
          _baseY = _baseY! * 0.994 + event.y * 0.006;
        }

        // Relative delta from natural resting holding angle (subtle playful response)
        final dx = ((event.x - _baseX!) / 3.2).clamp(-1.0, 1.0);
        final dy = ((event.y - _baseY!) / 3.2).clamp(-1.0, 1.0);

        // Store targets for the smooth ticker loop (gentle, subtle gyro depth)
        _targetTiltX = dx * 0.05;
        _targetTiltY = dy * 0.05;
      }, onError: (_) {
        // Sensors unavailable (e.g. desktop/simulator) - ignore gracefully
      });
    } catch (_) {}
  }

  /// Evaluates tilt position against the 4 directional edges and triggers crisp haptics upon entry
  void _checkEdgeHaptics(double x, double y) {
    const double threshold = 0.038; // Subtle angle limit to trigger side haptic
    const double resetMargin = 0.020; // Return toward center to re-arm

    // 1. Left side
    if (x < -threshold) {
      if (_hapticLeftArmed) {
        _hapticLeftArmed = false;
        unawaited(AppHaptics.lightImpact());
      }
    } else if (x > -resetMargin) {
      _hapticLeftArmed = true;
    }

    // 2. Right side
    if (x > threshold) {
      if (_hapticRightArmed) {
        _hapticRightArmed = false;
        unawaited(AppHaptics.lightImpact());
      }
    } else if (x < resetMargin) {
      _hapticRightArmed = true;
    }

    // 3. Top side (pitch forward/up)
    if (y < -threshold) {
      if (_hapticTopArmed) {
        _hapticTopArmed = false;
        unawaited(AppHaptics.lightImpact());
      }
    } else if (y > -resetMargin) {
      _hapticTopArmed = true;
    }

    // 4. Bottom side (pitch backward/down)
    if (y > threshold) {
      if (_hapticBottomArmed) {
        _hapticBottomArmed = false;
        unawaited(AppHaptics.lightImpact());
      }
    } else if (y < resetMargin) {
      _hapticBottomArmed = true;
    }
  }

  @override
  void dispose() {
    _tiltTicker.dispose();
    _sensorSubscription?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    if (_isSharing || !_isImagePrecached) return;

    await AppHaptics.mediumImpact();
    setState(() {
      _isSharing = true;
      _isExporting = true; // Reset tilt to zero for export capture
    });

    try {
      if (_precacheFuture != null) {
        try {
          await _precacheFuture!.timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      // Ensure next rendered frame with level tilt and decoded image is finished
      await WidgetsBinding.instance.endOfFrame;

      // Extract share button bounds for iPad/Mac share sheet anchor
      Rect? sharePositionOrigin;
      final renderBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final origin = renderBox.localToGlobal(Offset.zero);
        sharePositionOrigin = origin & renderBox.size;
      }

      final success = await ShareCardService.instance.sharePolaroidCard(
        boundaryKey: _boundaryKey,
        title: widget.title,
        mediaType: widget.mediaType,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted && success) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildScreenBlurredBackground(String? url) {
    if (url == null || url.isEmpty) {
      return Container(color: AppColors.background);
    }

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
      child: Transform.scale(
        scale: 1.35, // Prevent edge blur artifacts
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (context, errorUrl, error) => Container(
            color: AppColors.background,
          ),
        ),
      ),
    );
  }

  Widget _buildVignetteOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.40),
            Colors.black.withValues(alpha: 0.72),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Scaled-up Polaroid card size for a prominent hero visual
    final cardWidth = (screenWidth * 0.76).clamp(280.0, 325.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Underlying High-Res Polaroid Photo Export Boundary (Captures ONLY the standalone Polaroid)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.all(28), // Padding for the soft shadow
                  child: PolaroidShareCard(
                    title: widget.title,
                    imageUrl: widget.imageUrl,
                    rating: _currentRating,
                    watchedDate: widget.watchedDate,
                    showRating: true,
                    showDate: _showDate,
                    cardWidth: 320.0,
                    tiltX: 0.0,
                    tiltY: 0.0,
                    showBackground: false, // ONLY the Polaroid photo! No blurred background canvas!
                  ),
                ),
              ),
            ),
          ),

          // 1. Full-Screen Edge-to-Edge Colored Blurred Background
          Positioned.fill(
            child: _buildScreenBlurredBackground(widget.imageUrl),
          ),

          // 2. Cinematic Dark Vignette Overlay
          Positioned.fill(
            child: _buildVignetteOverlay(),
          ),

          // 3. Foreground Interactive UI
          SafeArea(
            child: Column(
              children: [
                // Top Header (Close button in horizontal center)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Center Scrollable Hero Area with Bouncing & Tilting Polaroid
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _cardFadeAnimation,
                            child: SlideTransition(
                              position: _cardSlideAnimation,
                              child: ScaleTransition(
                                scale: _cardScaleAnimation,
                                child: PolaroidShareCard(
                                  title: widget.title,
                                  imageUrl: widget.imageUrl,
                                  rating: _currentRating,
                                  watchedDate: widget.watchedDate,
                                  showRating: _showRating,
                                  showDate: _showDate,
                                  cardWidth: cardWidth,
                                  tiltX: _isExporting ? 0.0 : _tiltX,
                                  tiltY: _isExporting ? 0.0 : _tiltY,
                                  showBackground: false,
                                  onRatingChanged: (newRating) {
                                    setState(() {
                                      _currentRating = newRating;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Share Action Button (Sequentially Revealed)
                FadeTransition(
                  opacity: _controlsFadeAnimation,
                  child: SlideTransition(
                    position: _controlsSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Subtle Hint Text
                          Text(
                            'Tap stars to rate',
                            style: AppTextStyles.xsMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.60),
                              letterSpacing: 0.3,
                            ),
                          ),

                          AppSpacing.gapH12,

                          SizedBox(
                            key: _shareButtonKey,
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_isSharing || !_isImagePrecached)
                                  ? null
                                  : _handleShare,
                              icon: (_isSharing || !_isImagePrecached)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.share_rounded, size: 20),
                              label: Text(
                                _isSharing
                                    ? 'Generating Polaroid...'
                                    : (!_isImagePrecached
                                        ? 'Loading Image...'
                                        : 'Share to Stories & Friends'),
                                style: AppTextStyles.mdBold.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          AppSpacing.gapH8,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
