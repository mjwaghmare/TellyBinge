import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_image_viewer.dart';

class FeedbackCard extends StatelessWidget {
  final FeedbackItem item;
  final VoidCallback? onUpvote;
  final VoidCallback? onTap;

  const FeedbackCard({
    super.key,
    required this.item,
    this.onUpvote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isLight
              ? AppColors.borderLight
              : Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: Left upvote button + Right content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Upvote Button
                    _buildUpvoteButton(context, isLight),
                    const SizedBox(width: AppSpacing.md),

                    // 2. Main content area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges row: Category pill + Severity pill + Status pill
                          Row(
                            children: [
                              _buildCategoryPill(item.category, isLight),
                              if (item.severity != null &&
                                  item.severity!.isNotEmpty) ...[
                                const SizedBox(width: 6.0),
                                _buildSeverityPill(item.severity!, isLight),
                              ],
                              const SizedBox(width: 8.0),
                              _buildStatusPill(item.status, isLight),
                            ],
                          ),
                          const SizedBox(height: 10.0),

                          // Title
                          Text(
                            item.title,
                            style: AppTextStyles.mdBold.copyWith(
                              color: isLight
                                  ? AppColors.lightTextPrimary
                                  : AppColors.textPrimary,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6.0),

                          // Description
                          Text(
                            item.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sm.copyWith(
                              color: isLight
                                  ? AppColors.lightTextSecondary
                                  : AppColors.textSecondary,
                              height: 1.35,
                              fontSize: 13.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 3. Media Preview (if any)
                if (item.media.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(left: 60.0),
                    child: SizedBox(
                      height: 72.0,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: item.media.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8.0),
                        itemBuilder: (context, index) {
                          final mediaItem = item.media[index];
                          final isLocal = mediaItem.isLocal;

                          return GestureDetector(
                            onTap: () => FeedbackImageViewer.show(
                              context,
                              imagePath: mediaItem.path,
                              isLocal: isLocal,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.0),
                              child: Container(
                                width: 110.0,
                                height: 72.0,
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? Colors.grey[200]
                                      : Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: isLight
                                        ? AppColors.borderLight
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: isLocal
                                    ? (kIsWeb
                                        ? Image.network(
                                            mediaItem.path,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.image_outlined,
                                                  color: AppColors.textTertiary,
                                                  size: 20,
                                                ),
                                          )
                                        : Image.file(
                                            File(mediaItem.path),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.image_outlined,
                                                      color: AppColors.textTertiary,
                                                      size: 20,
                                                    ),
                                          ))
                                    : CachedNetworkImage(
                                        imageUrl: mediaItem.path,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator.adaptive(
                                                  strokeWidth: 2,
                                                ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.textTertiary,
                                              size: 20,
                                            ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isLight
                      ? AppColors.borderLight
                      : Colors.white.withValues(alpha: 0.06),
                ),
                const SizedBox(height: 10.0),

                // 4. Bottom Author / Metadata Row
                Row(
                  children: [
                    // Avatar circle
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          item.userName.isNotEmpty
                              ? item.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Username
                    Text(
                      item.userName,
                      style: AppTextStyles.xsMedium.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),

                    // App Version Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.grey[100]
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: isLight
                              ? AppColors.borderLight
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Text(
                        item.appVersion,
                        style: AppTextStyles.xs.copyWith(
                          color: isLight
                              ? AppColors.lightTextSecondary
                              : AppColors.textSecondary,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Timestamp
                    Text(
                      item.timeAgo,
                      style: AppTextStyles.xs.copyWith(
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : const Color(0xFF8E8E93),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SUB WIDGETS ---

  Widget _buildUpvoteButton(BuildContext context, bool isLight) {
    final isUpvoted = item.isUpvoted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onUpvote?.call();
        },
        borderRadius: BorderRadius.circular(12.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48.0,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isUpvoted
                ? AppColors.primary.withValues(alpha: isLight ? 0.15 : 0.22)
                : (isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1E1E2C)),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isUpvoted
                  ? AppColors.primary
                  : (isLight
                        ? AppColors.borderLight
                        : Colors.white.withValues(alpha: 0.08)),
              width: isUpvoted ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: isUpvoted
                    ? AppColors.primary
                    : (isLight ? AppColors.lightTextSecondary : Colors.white70),
                size: 22,
              ),
              const SizedBox(height: 1.0),
              Text(
                '${item.votes}',
                style: AppTextStyles.smBold.copyWith(
                  color: isUpvoted
                      ? AppColors.primary
                      : (isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(FeedbackCategory category, bool isLight) {
    final textColor = category.textColor(isLight);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: category.backgroundColor(isLight),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: textColor.withValues(alpha: isLight ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSeverityPill(String severity, bool isLight) {
    final textColor = isLight ? AppColors.error : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: textColor.withValues(alpha: isLight ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: textColor,
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusPill(FeedbackStatus status, bool isLight) {
    final textColor = status.textColor(isLight);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: status.backgroundColor(isLight),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: textColor.withValues(alpha: isLight ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
