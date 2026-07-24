import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class WatchTrailerButton extends StatelessWidget {
  final Map<String, dynamic> trailer;

  const WatchTrailerButton({super.key, required this.trailer});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  void _showTrailerBottomSheet(BuildContext context, Map<String, dynamic> trailer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TrailerBottomSheet(trailer: trailer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (trailer['site'] == 'YouTube') {
          _showTrailerBottomSheet(context, trailer);
        } else {
          String urlStr = '';
          if (trailer['site'] == 'Vimeo') {
            urlStr = 'https://vimeo.com/${trailer['key']}';
          }
          if (urlStr.isNotEmpty) {
            final url = Uri.parse(urlStr);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.inAppWebView);
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://img.youtube.com/vi/${trailer['key']}/0.jpg',
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 120,
                      height: 68,
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Watch trailer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trailer['name'] as String? ??
                        trailer['site'] as String? ??
                        'Trailer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trailer['published_at'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(trailer['published_at'] as String),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerBottomSheet extends StatefulWidget {
  final Map<String, dynamic> trailer;
  const _TrailerBottomSheet({required this.trailer});

  @override
  State<_TrailerBottomSheet> createState() => _TrailerBottomSheetState();
}

class _TrailerBottomSheetState extends State<_TrailerBottomSheet> {
  late YoutubePlayerController _controller;
  late DraggableScrollableController _dragController;
  double? _minExtent;
  bool _isClosing = false;
  bool _dragStartedAtMin = true;
  bool _isVideoPlaying = true; // Auto-play is enabled by default
  static const double _maxExtent = 0.9;

  @override
  void initState() {
    super.initState();
    _dragController = DraggableScrollableController();
    _dragController.addListener(_onDragChanged);

    final videoKey = widget.trailer['key'] as String;
    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoKey,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        mute: false,
      ),
    );
  }

  void _onDragChanged() {
    if (!_dragController.isAttached || _isClosing || _minExtent == null) return;
    
    final size = _dragController.size;
    final minExtent = _minExtent!;

    // Dismiss the sheet when dragged below minExtent - 0.05, but only if the drag started from minExtent
    if (_dragStartedAtMin && size < minExtent - 0.05) {
      _isClosing = true;
      Navigator.of(context).pop();
      return;
    }

    // Check if the sheet is stable (close to minExtent or _maxExtent)
    final bool isNearMin = (size - minExtent).abs() < 0.005;
    final bool isNearMax = (size - _maxExtent).abs() < 0.005;

    if (isNearMin || isNearMax) {
      if (!_isVideoPlaying) {
        _isVideoPlaying = true;
        _controller.playVideo();
      }
    } else {
      if (_isVideoPlaying) {
        _isVideoPlaying = false;
        _controller.pauseVideo();
      }
    }
  }

  @override
  void dispose() {
    _dragController.removeListener(_onDragChanged);
    _dragController.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenW = screenSize.width;
    final screenH = screenSize.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    const double handleHeight = 40.0; // 24px top padding + 4px handle + 12px bottom padding
    const double topMargin = 16.0; // Margin between drag handle and video player
    const double bottomPaddingValue = 24.0; // Same as top handle padding
    final double playerH = screenW * 9 / 16;
    final double initialHeight = handleHeight + topMargin + playerH + bottomPaddingValue + bottomPadding;

    _minExtent ??= (initialHeight / screenH).clamp(0.15, 0.85);
    final double minExtent = _minExtent!;
    // Allow dragging down below minExtent to trigger the dismissal listener
    final double minChildSize = (minExtent - 0.1).clamp(0.05, 0.85);

    return Listener(
      onPointerDown: (event) {
        if (_dragController.isAttached) {
          _dragStartedAtMin = (_dragController.size - minExtent).abs() < 0.05;
        }
      },
      child: DraggableScrollableSheet(
        controller: _dragController,
        initialChildSize: minExtent,
        minChildSize: minChildSize,
        maxChildSize: _maxExtent,
        expand: false,
        snap: true,
        snapSizes: [minExtent, _maxExtent],
        builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double currentSheetHeight = constraints.maxHeight;
            final double extent = currentSheetHeight / screenH;

            final double t = ((extent - minExtent) / (_maxExtent - minExtent)).clamp(0.0, 1.0);

            // Determine target dimensions and rotation based on physical device orientation
            final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

            final double angle = isLandscape ? 0.0 : t * (math.pi / 2);

            final double playerW0 = screenW;
            final double playerH0 = screenW * 9 / 16;

            final double playerW1;
            final double playerH1;

            if (isLandscape) {
              // In physical landscape mode, fit to screen width and height cleanly without rotation
              playerW1 = math.min(screenW - 32.0, (screenH - handleHeight - topMargin - bottomPaddingValue - bottomPadding) * 16 / 9);
              playerH1 = playerW1 * 9 / 16;
            } else {
              // In portrait mode, rotate to landscape on drag up
              playerW1 = math.min(screenH * _maxExtent - (handleHeight + topMargin + bottomPaddingValue), screenW * 16 / 9);
              playerH1 = playerW1 * 9 / 16;
            }

            // Interpolate current layout width and height
            final double currentLayoutW = playerW0 + t * (playerW1 - playerW0);
            final double currentLayoutH = playerH0 + t * (playerH1 - playerH0);

            // Interpolate position relative to sheet top
            final double currentCenterSheet;
            if (isLandscape) {
              // Centered below the handle in landscape mode
              currentCenterSheet = handleHeight + topMargin + currentLayoutH / 2;
            } else {
              // Anchored position below the handle: keep top at handleHeight + topMargin in portrait mode
              currentCenterSheet = handleHeight + topMargin + (playerH0 + t * (playerW1 - playerH0)) / 2;
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                clipBehavior: Clip.none, // Allow rotated player to render outside scroll viewport without clipping during transition
                child: SizedBox(
                  height: currentSheetHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: Container(
                            height: 4,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: screenW / 2 - currentLayoutW / 2,
                        top: currentCenterSheet - currentLayoutH / 2,
                        width: currentLayoutW,
                        height: currentLayoutH,
                        child: Transform.rotate(
                          angle: angle,
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: YoutubePlayer(
                              controller: _controller,
                              aspectRatio: currentLayoutW / currentLayoutH,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
}
