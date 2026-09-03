import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_media_preview.dart';
import 'feedback_pill.dart';

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
                          // Badges row: Milestone pill (if any, FIRST) + Category pill + Severity pill + Status pill
                          Wrap(
                            spacing: 6.0,
                            runSpacing: 4.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (item.voteMilestone != null)
                                FeedbackPill.milestone(
                                  milestone: item.voteMilestone!,
                                  isLight: isLight,
                                ),
                              FeedbackPill.category(
                                category: item.category,
                                isLight: isLight,
                              ),
                              if (item.severity != null &&
                                  item.severity!.isNotEmpty)
                                FeedbackPill.severity(
                                  severity: item.severity!,
                                  isLight: isLight,
                                ),
                              FeedbackPill.status(
                                status: item.status,
                                isLight: isLight,
                              ),
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
                    child: FeedbackMediaPreview(
                      media: item.media,
                      isLight: isLight,
                      size: 54.0,
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

    final borderColor = isUpvoted
        ? AppColors.primary
        : (isLight
            ? AppColors.borderLight
            : Colors.white.withValues(alpha: 0.12));

    final numberColor = isUpvoted
        ? AppColors.primary
        : (isLight ? AppColors.lightTextPrimary : AppColors.textPrimary);

    final arrowColor = isUpvoted
        ? AppColors.primary
        : (isLight ? AppColors.lightTextSecondary : Colors.white60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onUpvote?.call();
        },
        borderRadius: BorderRadius.circular(12.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50.0,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 3.0),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: borderColor,
              width: isUpvoted ? 1.4 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: arrowColor,
                size: 23,
              ),
              const SizedBox(height: 1.0),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.formattedVotes,
                  maxLines: 1,
                  style: TextStyle(
                    color: numberColor,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.1,
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
