import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/services/feedback_duplicate_detector.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../data/repositories/feedback_repository_impl.dart';
import '../../data/services/feedback_submission_guard.dart';
import 'feedback_image_viewer.dart';

class SubmitFeedbackSheet extends StatefulWidget {
  final ValueChanged<FeedbackItem>? onSubmit;
  final FeedbackRepository? feedbackRepository;
  final List<FeedbackItem> existingItems;

  const SubmitFeedbackSheet({
    super.key,
    this.onSubmit,
    this.feedbackRepository,
    this.existingItems = const [],
  });

  static Future<FeedbackItem?> show(
    BuildContext context, {
    ValueChanged<FeedbackItem>? onSubmit,
    FeedbackRepository? feedbackRepository,
    List<FeedbackItem> existingItems = const [],
  }) {
    final isLight = context.isLight;
    return showModalBottomSheet<FeedbackItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isLight ? AppColors.lightSurfaceElevated : AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) => SubmitFeedbackSheet(
        onSubmit: onSubmit,
        feedbackRepository: feedbackRepository,
        existingItems: existingItems,
      ),
    );
  }

  @override
  State<SubmitFeedbackSheet> createState() => _SubmitFeedbackSheetState();
}

class _SubmitFeedbackSheetState extends State<SubmitFeedbackSheet> {
  late final FeedbackRepository _repository;
  final FeedbackSubmissionGuard _submissionGuard = FeedbackSubmissionGuard();
  FeedbackCategory _selectedCategory = FeedbackCategory.bug;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _attachedMedia = [];
  bool _isSubmitting = false;

  // Bug severity default is Minor
  String _selectedSeverity = 'Minor';

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickGalleryMedia() async {
    if (_isSubmitting) return;
    if (_attachedMedia.length >= 5) {
      AppSnackbar.showInfo(context, 'You can attach up to 5 images.');
      return;
    }
    HapticFeedback.lightImpact();
    final remainingSlots = 5 - _attachedMedia.length;
    try {
      final images = await _picker.pickMultiImage(
        limit: remainingSlots,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (images.isNotEmpty && mounted) {
        setState(() {
          _attachedMedia.addAll(images.take(remainingSlots));
        });
        return;
      }
    } catch (_) {
      // Fallback to single pick if pickMultiImage encounters platform limitations
      try {
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        if (image != null && mounted) {
          setState(() {
            _attachedMedia.add(image);
          });
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Failed to attach image from gallery. Please check storage permissions.',
          );
        }
      }
    }
  }

  void _removeMedia(int index) {
    if (_isSubmitting) return;
    HapticFeedback.lightImpact();
    setState(() {
      _attachedMedia.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      AppSnackbar.showInfo(context, 'Please enter a title');
      return;
    }

    if (message.isEmpty) {
      AppSnackbar.showInfo(context, 'Please enter a description / message');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? '';
      final userName =
          user?.displayName ??
          (user?.email != null && user!.email!.contains('@')
              ? user.email!.split('@').first
              : 'PopVerse User');
      final userAvatar = user?.photoURL ?? '';

      final duplicate = FeedbackDuplicateDetector.findDuplicate(
        existingItems: widget.existingItems,
        title: title,
        description: message,
        category: _selectedCategory,
      );
      if (duplicate != null) {
        if (mounted) setState(() => _isSubmitting = false);
        AppSnackbar.showInfo(
          context,
          'A matching feedback item already exists. Add an upvote or comment instead.',
        );
        return;
      }

      final remainingCooldown = await _submissionGuard.remainingCooldown(
        userId,
      );
      if (!mounted) return;
      if (remainingCooldown != null) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showInfo(
          context,
          'Please wait ${remainingCooldown.inSeconds + 1}s before submitting again.',
        );
        return;
      }

      String appVersion = 'v1.0.0';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = 'v${info.version}+${info.buildNumber}';
      } catch (_) {}

      final newItem = await _repository.submitFeedback(
        title: title,
        description: message,
        category: _selectedCategory,
        severity: _selectedCategory == FeedbackCategory.bug
            ? _selectedSeverity
            : null,
        localMediaPaths: _attachedMedia.map((f) => f.path).toList(),
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        appVersion: appVersion,
      );

      await _submissionGuard.recordSubmission(userId);
      if (mounted) {
        widget.onSubmit?.call(newItem);
        Navigator.pop(context, newItem);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        final errorStr = e.toString().toLowerCase();
        final String message;
        if (errorStr.contains('cloudinary configuration missing')) {
          message = 'Cloudinary configuration is missing in .env';
        } else if (errorStr.contains('cloudinary') || errorStr.contains('failed to upload image')) {
          message = 'Failed to upload media to Cloudinary. Please check credentials/network.';
        } else {
          message = 'Failed to submit feedback: $e';
        }
        AppSnackbar.showError(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4.0, bottom: 12.0),
                    decoration: BoxDecoration(
                      color: isLight ? AppColors.borderLight : AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Bar: Title + Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Feedback',
                      style: AppTextStyles.smBold.copyWith(
                        color: isLight
                            ? AppColors.lightTextSecondary
                            : AppColors.textTertiary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: AppTextStyles.smBold.copyWith(
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 3. Main Title & Subtitle
                Text(
                  'Submit your feedback',
                  style: AppTextStyles.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                    fontSize: 22.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Choose a category below to submit your feedback.',
                  style: AppTextStyles.sm.copyWith(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 13.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Category Segmented Pill Bar (Bug, Feature, Improvement)
                Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: Row(
                    children: [
                      _buildCategoryTab(FeedbackCategory.bug, 'Bug'),
                      _buildCategoryTab(FeedbackCategory.feature, 'Feature'),
                      _buildCategoryTab(
                        FeedbackCategory.improvement,
                        'Improvement',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Bug Severity Chips (Only for Bug category)
                if (_selectedCategory == FeedbackCategory.bug) ...[
                  _buildInputLabel('Severity', isLight),
                  Row(
                    children: [
                      _buildChoicePill(
                        'Minor',
                        _selectedSeverity == 'Minor',
                        () {
                          setState(() => _selectedSeverity = 'Minor');
                        },
                        isLight,
                      ),
                      const SizedBox(width: 8.0),
                      _buildChoicePill(
                        'Major',
                        _selectedSeverity == 'Major',
                        () {
                          setState(() => _selectedSeverity = 'Major');
                        },
                        isLight,
                      ),
                      const SizedBox(width: 8.0),
                      _buildChoicePill(
                        'Crash',
                        _selectedSeverity == 'Crash',
                        () {
                          setState(() => _selectedSeverity = 'Crash');
                        },
                        isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 6. Title Input with Character Limit (80 max)
                _buildFieldHeader(
                  'Title',
                  _titleController.text.length,
                  80,
                  isLight,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isLight
                          ? AppColors.borderLight
                          : AppColors.borderDark,
                    ),
                  ),
                  child: TextField(
                    controller: _titleController,
                    maxLength: 80,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.sm.copyWith(
                      color: isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      hintText: _getTitlePlaceholder(),
                      hintStyle: AppTextStyles.sm.copyWith(
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                        fontSize: 13.5,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 7. Message / Description Input with Character Limit (500 max)
                _buildFieldHeader(
                  'Description',
                  _messageController.text.length,
                  500,
                  isLight,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurfaceElevated
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isLight
                          ? AppColors.borderLight
                          : AppColors.borderDark,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLength: 500,
                    maxLines: 4,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.sm.copyWith(
                      color: isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: _getMessagePlaceholder(),
                      hintStyle: AppTextStyles.sm.copyWith(
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                        height: 1.35,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(14.0),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 8. Media Section (Header with '+ Add (Max 5)' button + Thumbnails)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Media',
                        style: AppTextStyles.smBold.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSubmitting ? null : _pickGalleryMedia,
                        child: Text(
                          '+ Add (Max 5)',
                          style: AppTextStyles.smBold.copyWith(
                            color: _attachedMedia.length >= 5
                                ? (isLight
                                    ? AppColors.lightTextTertiary
                                    : AppColors.textTertiary)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_attachedMedia.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  SizedBox(
                    height: 80.0,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachedMedia.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10.0),
                      itemBuilder: (context, index) {
                        final file = _attachedMedia[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => FeedbackImageViewer.show(
                                context,
                                mediaItems: _attachedMedia
                                    .map((f) => FeedbackMedia(
                                          path: f.path,
                                          isLocal: true,
                                        ))
                                    .toList(),
                                initialIndex: index,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  width: 80.0,
                                  height: 80.0,
                                  decoration: BoxDecoration(
                                    color: isLight
                                        ? AppColors.lightSurfaceElevated
                                        : AppColors.surfaceElevated,
                                    border: Border.all(
                                      color: isLight
                                          ? AppColors.borderLight
                                          : AppColors.borderDark,
                                    ),
                                  ),
                                  child: kIsWeb
                                      ? Image.network(
                                          file.path,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(
                                            Icons.broken_image_outlined,
                                            color:
                                                AppColors.textTertiary,
                                            size: 24,
                                          ),
                                        )
                                      : Image.file(
                                          File(file.path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(
                                            Icons.broken_image_outlined,
                                            color:
                                                AppColors.textTertiary,
                                            size: 24,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            // Delete badge (Red close)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textOnPrimary,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // 9. Submit Full-width Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textOnPrimary,
                              ),
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _getSubmitButtonText(),
                            style: AppTextStyles.mdBold.copyWith(
                              fontSize: 15.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SUB WIDGET BUILDERS ---

  Widget _buildCategoryTab(FeedbackCategory category, String label) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9.0),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.smMedium.copyWith(
                color: isSelected ? AppColors.textOnPrimary : AppColors.textTertiary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoicePill(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isLight,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isLight ? AppColors.lightSurfaceElevated : AppColors.surfaceElevated),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isLight
                      ? AppColors.borderLight
                      : AppColors.borderDark),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.xsMedium.copyWith(
            color: isSelected
                ? AppColors.textOnPrimary
                : (isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }



  Widget _buildInputLabel(String label, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: AppTextStyles.smBold.copyWith(
          color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFieldHeader(
    String label,
    int currentLength,
    int maxLength,
    bool isLight, {
    String? customSuffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.smBold.copyWith(
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          Text(
            customSuffix ?? '$currentLength/$maxLength',
            style: AppTextStyles.xs.copyWith(
              color: isLight
                  ? AppColors.lightTextTertiary
                  : AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitlePlaceholder() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return 'e.g. Episode notification not triggering';
      case FeedbackCategory.feature:
        return 'e.g. Filter Discover by streaming service';
      case FeedbackCategory.improvement:
        return 'e.g. Faster watchlist search & poster load';
    }
  }

  String _getMessagePlaceholder() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return 'Describe what happened, steps to reproduce, and what you expected to see...';
      case FeedbackCategory.feature:
        return 'Explain how you imagine this feature working and why it would improve your tracking experience in PopVerse...';
      case FeedbackCategory.improvement:
        return 'Tell us what part of PopVerse can be better (e.g. UI/UX, watchlist speed, stats, notifications) and what you suggest...';
    }
  }

  String _getSubmitButtonText() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return 'Submit Bug Report';
      case FeedbackCategory.feature:
        return 'Submit Feature Idea';
      case FeedbackCategory.improvement:
        return 'Submit Improvement';
    }
  }
}
