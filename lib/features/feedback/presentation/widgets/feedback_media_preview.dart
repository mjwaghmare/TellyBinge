import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_image_viewer.dart';
import 'feedback_media_image.dart';

class FeedbackMediaPreview extends StatelessWidget {
  final List<FeedbackMedia> media;
  final bool isLight;
  final double size;
  final int maxCount;
  final bool showAll;

  const FeedbackMediaPreview({
    super.key,
    required this.media,
    required this.isLight,
    this.size = 54.0,
    this.maxCount = 3,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    if (showAll) {
      return Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: List.generate(media.length, (index) {
          final mediaItem = media[index];
          return _buildThumbnail(
            context: context,
            mediaItem: mediaItem,
            index: index,
            overlayBadge: null,
          );
        }),
      );
    }

    // Show at most maxCount preview thumbnails (default 3)
    final displayCount = media.length > maxCount ? maxCount : media.length;
    final remainingCount = media.length - maxCount;

    return SizedBox(
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(displayCount, (index) {
          final isLastWithMore = index == maxCount - 1 && remainingCount > 0;
          final mediaItem = media[index];

          return Padding(
            padding: EdgeInsets.only(
              right: index < displayCount - 1 ? 8.0 : 0.0,
            ),
            child: _buildThumbnail(
              context: context,
              mediaItem: mediaItem,
              index: index,
              overlayBadge: isLastWithMore ? '+$remainingCount' : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildThumbnail({
    required BuildContext context,
    required FeedbackMedia mediaItem,
    required int index,
    String? overlayBadge,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FeedbackImageViewer.show(
        context,
        mediaItems: media,
        initialIndex: index,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail image
              Container(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.grey[200]
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isLight
                        ? AppColors.borderLight
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: FeedbackMediaImage(
                  media: mediaItem,
                  fit: BoxFit.cover,
                  placeholder: (_) => const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorBuilder: (_) => const Icon(
                    Icons.image_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ),
              ),

              // Overlay badge "+N" when more media items exist
              if (overlayBadge != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    overlayBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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
