import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_image_viewer.dart';
import 'feedback_media_image.dart';

class FeedbackMediaPreview extends StatelessWidget {
  final List<FeedbackMedia> media;
  final bool isLight;
  final double size;

  const FeedbackMediaPreview({
    super.key,
    required this.media,
    required this.isLight,
    this.size = 54.0,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    // Show at most 2 preview thumbnails
    final displayCount = media.length > 2 ? 2 : media.length;
    final remainingCount = media.length - 2;

    return SizedBox(
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(displayCount, (index) {
          final isSecondWithMore = index == 1 && remainingCount > 0;
          final mediaItem = media[index];

          return Padding(
            padding: EdgeInsets.only(
              right: index < displayCount - 1 ? 8.0 : 0.0,
            ),
            child: GestureDetector(
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

                      // Overlay badge "+N" when more than 2 media items exist
                      if (isSecondWithMore)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$remainingCount',
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
            ),
          );
        }),
      ),
    );
  }
}
