import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_media_image.dart';

class FeedbackImageViewer extends StatefulWidget {
  final List<FeedbackMedia> mediaItems;
  final int initialIndex;

  const FeedbackImageViewer({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
  });

  static void show(
    BuildContext context, {
    List<FeedbackMedia>? mediaItems,
    int initialIndex = 0,
    String? imagePath,
    bool isLocal = false,
  }) {
    HapticFeedback.lightImpact();
    final items = mediaItems ??
        (imagePath != null && imagePath.isNotEmpty
            ? [FeedbackMedia(path: imagePath, isLocal: isLocal)]
            : const <FeedbackMedia>[]);

    if (items.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => FeedbackImageViewer(
        mediaItems: items,
        initialIndex: items.isEmpty
            ? 0
            : initialIndex.clamp(0, items.length - 1),
      ),
    );
  }

  @override
  State<FeedbackImageViewer> createState() => _FeedbackImageViewerState();
}

class _FeedbackImageViewerState extends State<FeedbackImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.mediaItems.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.mediaItems.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.mediaItems.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Swipeable PageView with pinch-to-zoom for each image
            PageView.builder(
              controller: _pageController,
              itemCount: totalCount,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final mediaItem = widget.mediaItems[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: FeedbackMediaImage(
                      media: mediaItem,
                      fit: BoxFit.contain,
                      placeholder: (_) => const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                      errorBuilder: (_) => _buildErrorWidget(),
                    ),
                  ),
                );
              },
            ),

            // 2. Top Bar: Counter (e.g. "1 / 3") + Close Button
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page counter (if multiple images)
                  if (totalCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / $totalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Bottom Indicator Dots (if multiple images)
            if (totalCount > 1)
              Positioned(
                bottom: AppSpacing.md,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalCount, (index) {
                    final isSelected = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3.0),
                      width: isSelected ? 18.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiary,
          size: 48,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Failed to load image',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      ],
    );
  }
}
