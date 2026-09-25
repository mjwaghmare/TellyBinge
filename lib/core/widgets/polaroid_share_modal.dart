import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../constants/app_constants.dart';
import '../network/tmdb_client.dart';
import '../services/app_haptics.dart';
import '../services/share_card_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/tmdb_artwork.dart';
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

  /// TMDB id of the title. When given together with [mediaType], alternate
  /// posters and backdrops are fetched and offered in a picker strip.
  final int? tmdbId;

  /// The `images` block of the title's details response. When given, the
  /// picker is built from it instantly instead of fetching by [tmdbId].
  final Map<String, dynamic>? images;

  const PolaroidShareModal({
    super.key,
    required this.title,
    this.imageUrl,
    this.rating,
    this.watchedDate,
    this.mediaType,
    this.tmdbId,
    this.images,
  });

  /// Convenient helper to display the modal screen sliding up from the bottom.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? imageUrl,
    double? rating,
    DateTime? watchedDate,
    String? mediaType,
    int? tmdbId,
    Map<String, dynamic>? images,
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
          tmdbId: tmdbId,
          images: images,
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _boundaryKey = GlobalKey();
  late bool _showRating;
  final bool _showDate = true;
  double? _currentRating;
  bool _isSharing = false;
  bool _isExporting = false;
  bool _isDismissing = false;

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

  // Artwork picker. [_selectedImageUrl] follows the user's tap immediately;
  // [_displayedImageUrl] (what the card renders and exports) only catches up
  // once that image has decoded, so Share never captures a blank frame.
  List<_ArtworkOption> _artworkOptions = const [];
  String? _selectedImageUrl;
  String? _displayedImageUrl;

  bool get _isImageReady =>
      _isImagePrecached && _selectedImageUrl == _displayedImageUrl;

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
    _selectedImageUrl = widget.imageUrl;
    _displayedImageUrl = widget.imageUrl;

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

    // Alternate artwork is optional: the strip only appears if there's any.
    final images = widget.images;
    if (images != null) {
      _artworkOptions = _artworkOptionsFrom(images);
    } else {
      unawaited(_fetchArtworkOptions());
    }

    // 3. Smooth Display-Synchronized Ticker (interpolates device tilt at 60/120Hz)
    _tiltTicker = createTicker((_) {
      if (!mounted || _isExporting || _isDismissing) return;

      final targetX = _targetTiltX.clamp(-0.10, 0.10);
      final targetY = _targetTiltY.clamp(-0.10, 0.10);

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

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.isReducedMotion(context)) {
      _stopSensorsAndTicker();
      if (_tiltX != 0.0 || _tiltY != 0.0) {
        setState(() {
          _tiltX = 0.0;
          _tiltY = 0.0;
        });
      }
    } else if (!_isDismissing && !_isExporting) {
      _startSensorsAndTicker();
    }
  }

  void _startSensorsAndTicker() {
    if (_isDismissing || _isExporting || !mounted) return;
    if (AppMotion.isReducedMotion(context)) return;

    if (!_tiltTicker.isTicking) {
      _tiltTicker.start();
    }
    if (_sensorSubscription == null) {
      try {
        _sensorSubscription = accelerometerEventStream().listen((event) {
          if (!mounted || _isExporting || _isDismissing) return;

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
          final dx = ((event.x - _baseX!) / 2.6).clamp(-1.0, 1.0);
          final dy = ((event.y - _baseY!) / 2.6).clamp(-1.0, 1.0);

          // Store targets for the smooth ticker loop (~5° max, noticeable gyro depth)
          _targetTiltX = dx * 0.09;
          _targetTiltY = dy * 0.09;
        }, onError: (_) {
          // Sensors unavailable (e.g. desktop/simulator) - ignore gracefully
        });
      } catch (_) {}
    }
  }

  void _stopSensorsAndTicker() {
    if (_tiltTicker.isTicking) {
      _tiltTicker.stop();
    }
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      _stopSensorsAndTicker();
    } else if (!_isDismissing && !_isExporting && mounted) {
      _startSensorsAndTicker();
    }
  }

  void _handleDismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _stopSensorsAndTicker();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Evaluates tilt position against the 4 directional edges and triggers crisp haptics upon entry
  void _checkEdgeHaptics(double x, double y) {
    if (_isDismissing || !mounted || AppMotion.isReducedMotion(context)) return;
    const double threshold = 0.068; // Subtle angle limit to trigger side haptic
    const double resetMargin = 0.036; // Return toward center to re-arm

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
    WidgetsBinding.instance.removeObserver(this);
    _isDismissing = true;
    _stopSensorsAndTicker();
    _tiltTicker.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  /// Fetches TMDB posters/backdrops for the picker strip.
  ///
  /// Only called when the caller didn't pass [PolaroidShareModal.images]
  /// (e.g. details served from an older cache entry without them).
  Future<void> _fetchArtworkOptions() async {
    final id = widget.tmdbId;
    final mediaType = widget.mediaType;
    if (id == null || mediaType == null) return;

    final data = await context.read<TmdbClient>().getMediaImages(mediaType, id);
    if (!mounted) return;

    final options = _artworkOptionsFrom(data);
    if (options.isEmpty) return;
    setState(() => _artworkOptions = options);
  }

  /// Opening image first, then the best posters (which fit the card's frame)
  /// and backdrops. Empty when there'd be nothing to choose between.
  List<_ArtworkOption> _artworkOptionsFrom(Map<String, dynamic> images) {
    final options = <_ArtworkOption>[];
    final seen = <String>{};
    void add(_ArtworkOption option) {
      if (seen.add(option.fullUrl)) options.add(option);
    }

    final initial = widget.imageUrl;
    if (initial != null && initial.isNotEmpty) {
      add(_ArtworkOption(thumbUrl: initial, fullUrl: initial));
    }
    for (final path in [
      // ~10 total: enough that the strip visibly scrolls, few enough that
      // it stays a quick choice. Backdrops crop to half their width in the
      // card's frame, so they get fewer slots.
      ...TmdbArtwork.topPaths(images, 'posters', limit: 6),
      ...TmdbArtwork.topPaths(images, 'backdrops', limit: 4),
    ]) {
      add(_ArtworkOption(
        thumbUrl: AppConstants.tmdbImageUrl(path, size: 'w185'),
        fullUrl: AppConstants.tmdbImageUrl(path, size: 'w780'),
      ));
    }

    return options.length < 2 ? const [] : options;
  }

  /// Selects [url] right away, but only swaps the card image once it has
  /// decoded. A later tap supersedes an in-flight load; a failed load reverts
  /// the selection to what the card is still showing.
  void _selectArtwork(String url) {
    if (_isSharing || url == _selectedImageUrl) return;
    unawaited(AppHaptics.selectionClick());
    setState(() => _selectedImageUrl = url);

    var failed = false;
    final future = precacheImage(
      CachedNetworkImageProvider(url),
      context,
      onError: (_, _) => failed = true,
    );
    _precacheFuture = future;
    future.whenComplete(() {
      if (!mounted || _selectedImageUrl != url) return;
      setState(() {
        if (failed) {
          _selectedImageUrl = _displayedImageUrl;
        } else {
          _displayedImageUrl = url;
          _isImagePrecached = true;
        }
      });
    });
  }

  Future<void> _handleShare() async {
    if (_isSharing || !_isImageReady) return;

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
        _handleDismiss();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _isExporting = false;
        });
        if (!_isDismissing) {
          _startSensorsAndTicker();
        }
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

  /// Horizontal strip of artwork thumbnails, cropped to the card's photo
  /// aspect ratio so each one previews exactly what the Polaroid will show.
  Widget _buildArtworkStrip() {
    const thumbWidth = 54.0;
    const thumbHeight = thumbWidth / 0.84;

    return SizedBox(
      height: thumbHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _artworkOptions.length,
        separatorBuilder: (_, _) => AppSpacing.gapW8,
        itemBuilder: (context, index) {
          final option = _artworkOptions[index];
          final isSelected = option.fullUrl == _selectedImageUrl;
          final isLoading = isSelected && option.fullUrl != _displayedImageUrl;

          return GestureDetector(
            onTap: () => _selectArtwork(option.fullUrl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: thumbWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.22),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: option.thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.white.withValues(alpha: 0.08)),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    if (isLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
    final isReduced = AppMotion.isReducedMotion(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Scaled-up Polaroid card size for a prominent hero visual
    final cardWidth = (screenWidth * 0.76).clamp(280.0, 325.0);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _isDismissing = true;
          _stopSensorsAndTicker();
        }
      },
      child: Scaffold(
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
                    imageUrl: _displayedImageUrl,
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

          // Opaque cover over the export boundary. The blurred background is
          // transparent while its image loads or cross-fades, which would let
          // the offscreen export copy show through. Capture is unaffected:
          // RepaintBoundary.toImage renders its own layer regardless.
          const Positioned.fill(
            child: ColoredBox(color: Colors.black),
          ),

          // 1. Full-Screen Edge-to-Edge Colored Blurred Background
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              // Fade the incoming image in over the outgoing one at full
              // opacity, rather than dipping both to half-transparent.
              transitionBuilder: (child, animation) =>
                  child.key == ValueKey(_displayedImageUrl)
                      ? FadeTransition(opacity: animation, child: child)
                      : child,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(_displayedImageUrl),
                child: _buildScreenBlurredBackground(_displayedImageUrl),
              ),
            ),
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
                            onPressed: _handleDismiss,
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
                              position: isReduced
                                  ? const AlwaysStoppedAnimation(Offset.zero)
                                  : _cardSlideAnimation,
                              child: ScaleTransition(
                                scale: isReduced
                                    ? const AlwaysStoppedAnimation(1.0)
                                    : _cardScaleAnimation,
                                child: PolaroidShareCard(
                                  title: widget.title,
                                  imageUrl: _displayedImageUrl,
                                  rating: _currentRating,
                                  watchedDate: widget.watchedDate,
                                  showRating: _showRating,
                                  showDate: _showDate,
                                  cardWidth: cardWidth,
                                  tiltX: (_isExporting || isReduced) ? 0.0 : _tiltX,
                                  tiltY: (_isExporting || isReduced) ? 0.0 : _tiltY,
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
                    position: isReduced
                        ? const AlwaysStoppedAnimation(Offset.zero)
                        : _controlsSlideAnimation,
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

                          // Alternate artwork picker (grows in once fetched)
                          AnimatedSize(
                            duration: isReduced
                                ? AppMotion.instant
                                : const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            child: _artworkOptions.isEmpty
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: _buildArtworkStrip(),
                                  ),
                          ),

                          SizedBox(
                            key: _shareButtonKey,
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_isSharing || !_isImageReady)
                                  ? null
                                  : _handleShare,
                              icon: (_isSharing || !_isImageReady)
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
                                    : (!_isImageReady
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
      ),
    );
  }
}

/// One choice in the artwork picker: a small image for the strip and the
/// full-size image the Polaroid renders and exports.
class _ArtworkOption {
  final String thumbUrl;
  final String fullUrl;

  const _ArtworkOption({required this.thumbUrl, required this.fullUrl});
}
