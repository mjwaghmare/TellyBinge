import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/models/feedback_item.dart';
import 'feedback_image_viewer.dart';

/// A modern, industry-standard comment tile for the feedback discussion.
/// Displays user avatar with network caching and initial fallback,
/// OP (Author) badge, relative time, clean typography, and an actions sheet.
class FeedbackCommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isOp;
  final bool isOwner;
  final String formattedTime;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FeedbackCommentTile({
    super.key,
    required this.comment,
    required this.isOp,
    required this.isOwner,
    required this.formattedTime,
    this.onEdit,
    this.onDelete,
  });

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  Widget _buildAvatar(BuildContext context, bool isLight) {
    final avatarUrl = (comment['userAvatar'] as String? ?? '').trim();
    final userName = (comment['name'] as String? ?? 'User').trim();
    final initials = _getInitials(userName);

    if (avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        imageBuilder: (context, imageProvider) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            border: Border.all(
              color: isLight ? AppColors.borderLight : AppColors.borderDark,
              width: 1.0,
            ),
          ),
        ),
        placeholder: (context, url) => _buildInitialsAvatar(initials, isLight),
        errorWidget: (context, url, error) =>
            _buildInitialsAvatar(initials, isLight),
      );
    }

    return _buildInitialsAvatar(initials, isLight);
  }

  Widget _buildInitialsAvatar(String initials, bool isLight) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isLight
              ? [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primaryLight.withValues(alpha: 0.22),
                ]
              : [
                  AppColors.surfaceElevated,
                  AppColors.primaryDark.withValues(alpha: 0.35),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isLight
              ? AppColors.borderLight
              : AppColors.primary.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Text(
        initials,
        style: AppTextStyles.xsBold.copyWith(
          color: isLight ? AppColors.primaryDark : AppColors.primaryLight,
          fontSize: 12.0,
        ),
      ),
    );
  }

  void _showCommentActionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final isLight = context.isLight;
    final commentText = comment['text'] as String? ?? '';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isLight
          ? AppColors.lightSurface
          : AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.borderLight
                        : AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Copy Comment Option (Available to all)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  leading: Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                  ),
                  title: Text(
                    'Copy text',
                    style: AppTextStyles.smMedium.copyWith(
                      color: isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: commentText));
                    AppSnackbar.showSuccess(
                      context,
                      'Comment copied to clipboard',
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),

                // Owner options: Edit & Delete
                if (isOwner) ...[
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    leading: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary,
                    ),
                    title: Text(
                      'Edit comment',
                      style: AppTextStyles.smMedium.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onEdit?.call();
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Delete comment',
                      style: AppTextStyles.smMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete?.call();
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final rawName = (comment['name'] as String? ?? 'PopVerse User').trim();
    final displayName = rawName.length > 12
        ? '${rawName.substring(0, 12)}...'
        : rawName;
    final commentText = comment['text'] as String? ?? '';

    return InkWell(
      onLongPress: () => _showCommentActionSheet(context),
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isLight ? AppColors.lightSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isLight
                ? AppColors.borderLight
                : AppColors.borderDark.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Avatar
            _buildAvatar(context, isLight),
            const SizedBox(width: AppSpacing.sm),

            // 2. Main Content (Header + Body)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Info Row
                  Row(
                    children: [
                      // User Info & Badges
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.smBold.copyWith(
                                  color: isLight
                                      ? AppColors.lightTextPrimary
                                      : AppColors.textPrimary,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),

                            // OP / Author Badge
                            if (isOp) ...[
                              AppSpacing.gapW4,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxs,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: isLight ? 0.12 : 0.22,
                                  ),
                                  borderRadius: BorderRadius.circular(6.0),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Author',
                                  style: AppTextStyles.xsMedium.copyWith(
                                    color: isLight
                                        ? AppColors.primaryDark
                                        : AppColors.primaryLight,
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            AppSpacing.gapW4,
                            Text(
                              '•',
                              style: AppTextStyles.xs.copyWith(
                                color: isLight
                                    ? AppColors.lightTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            AppSpacing.gapW4,

                            // Timestamp
                            Text(
                              formattedTime,
                              style: AppTextStyles.xs.copyWith(
                                color: isLight
                                    ? AppColors.lightTextTertiary
                                    : AppColors.textTertiary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action button (3-dots)
                      InkWell(
                        onTap: () => _showCommentActionSheet(context),
                        borderRadius: BorderRadius.circular(16.0),
                        child: Padding(
                          padding: AppSpacing.allXXS,
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 18.0,
                            color: isLight
                                ? AppColors.lightTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2.0),

                  // Comment Body Text
                  if (commentText.isNotEmpty)
                    Text(
                      commentText,
                      style: AppTextStyles.sm.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textSecondary,
                        height: 1.45,
                        fontSize: 13.5,
                      ),
                    ),

                  // Attached Media Image (if any)
                  if ((comment['imageUrl'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6.0),
                    _buildCommentImage(
                      context,
                      (comment['imageUrl'] as String).trim(),
                      isLight,
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

  Widget _buildCommentImage(BuildContext context, String path, bool isLight) {
    final isLocal = !path.startsWith('http://') && !path.startsWith('https://');
    return GestureDetector(
      onTap: () => FeedbackImageViewer.show(
        context,
        mediaItems: [FeedbackMedia(path: path, isLocal: isLocal)],
        initialIndex: 0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 220.0,
            maxHeight: 160.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: isLight
                  ? AppColors.borderLight
                  : AppColors.borderDark.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: isLocal
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                )
              : CachedNetworkImage(
                  imageUrl: path,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 120.0,
                    height: 100.0,
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 120.0,
                    height: 100.0,
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      size: 24,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
