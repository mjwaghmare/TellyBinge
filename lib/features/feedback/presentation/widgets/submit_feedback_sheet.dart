import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';

class SubmitFeedbackSheet extends StatefulWidget {
  final ValueChanged<FeedbackItem> onSubmit;

  const SubmitFeedbackSheet({super.key, required this.onSubmit});

  static Future<void> show(BuildContext context, {required ValueChanged<FeedbackItem> onSubmit}) {
    final isLight = context.isLight;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? Colors.white : const Color(0xFF161622),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (context) => SubmitFeedbackSheet(onSubmit: onSubmit),
    );
  }

  @override
  State<SubmitFeedbackSheet> createState() => _SubmitFeedbackSheetState();
}

class _SubmitFeedbackSheetState extends State<SubmitFeedbackSheet> {
  FeedbackCategory _selectedCategory = FeedbackCategory.bug;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _attachedMedia = [];

  // Dynamic tags
  String _selectedSeverity = 'Major';
  String _selectedFeatureTag = 'Sync';
  String _selectedImprovementArea = 'Performance';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    try {
      final image = await _picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
      if (image != null && mounted) {
        setState(() {
          _attachedMedia.add(image);
        });
      }
    } catch (_) {}
  }

  void _removeMedia(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _attachedMedia.removeAt(index);
    });
  }

  void _handleSubmit() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description / message')));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    final newItem = FeedbackItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: message,
      category: _selectedCategory,
      status: FeedbackStatus.open,
      votes: 1,
      mediaUrls: _attachedMedia.map((f) => f.path).toList(),
      userName: 'You',
      userAvatar: '',
      appVersion: 'v1.0.0',
      timeAgo: 'Just now',
      isUpvoted: true,
    );

    widget.onSubmit(newItem);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
                    color: isLight ? Colors.grey[300] : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Header Bar: Title + Done Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Feedback',
                    style: TextStyle(
                      color: isLight ? AppColors.lightTextSecondary : const Color(0xFF8E8E93),
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: AppColors.primaryLight, fontSize: 15.0, fontWeight: FontWeight.w600),
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
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                  fontSize: 22.0,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Choose a category below to submit your feedback.',
                style: AppTextStyles.sm.copyWith(
                  color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                  fontSize: 13.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Category Segmented Pill Bar (Bug, Feature, Improvement)
              Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Row(
                  children: [
                    _buildCategoryTab(FeedbackCategory.bug, 'Bug'),
                    _buildCategoryTab(FeedbackCategory.feature, 'Feature'),
                    _buildCategoryTab(FeedbackCategory.improvement, 'Improvement'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5. Dynamic Category Fields
              ..._buildCategorySpecificFields(isLight),

              // 6. Title Input
              _buildInputLabel('Title', isLight),
              Container(
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF9FAFB) : const Color(0xFF1B182B),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: _getTitlePlaceholder(),
                    hintStyle: TextStyle(
                      color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 7. Message / Description Input
              _buildInputLabel('Description', isLight),
              Container(
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFF9FAFB) : const Color(0xFF1B182B),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  style: TextStyle(
                    color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: _getMessagePlaceholder(),
                    hintStyle: TextStyle(
                      color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14.0),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 8. Media Section (Camera + Upload buttons + Thumbnails)
              _buildInputLabel('Media', isLight),
              SizedBox(
                height: 84.0,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Camera picker button
                    _buildMediaPickerButton(
                      icon: Icons.camera_alt_outlined,
                      onTap: () => _pickImage(ImageSource.camera),
                      isLight: isLight,
                    ),
                    const SizedBox(width: 10.0),

                    // Gallery upload button
                    _buildMediaPickerButton(
                      icon: Icons.file_upload_outlined,
                      label: '+ Upload',
                      onTap: () => _pickImage(ImageSource.gallery),
                      isLight: isLight,
                    ),
                    const SizedBox(width: 10.0),

                    // Attached Media Previews
                    ..._attachedMedia.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                width: 84.0,
                                height: 84.0,
                                decoration: BoxDecoration(
                                  border: Border.all(color: isLight ? AppColors.borderLight : Colors.white24),
                                ),
                                child: Image.file(File(file.path), fit: BoxFit.cover),
                              ),
                            ),
                            // Delete badge (Red trash)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeMedia(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 9. Submit Full-width Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _getSubmitButtonText(),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorySpecificFields(bool isLight) {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return [
          _buildInputLabel('Severity', isLight),
          Row(
            children: [
              _buildChoicePill('Minor', _selectedSeverity == 'Minor', () {
                setState(() => _selectedSeverity = 'Minor');
              }, isLight),
              const SizedBox(width: 8.0),
              _buildChoicePill('Major', _selectedSeverity == 'Major', () {
                setState(() => _selectedSeverity = 'Major');
              }, isLight),
              const SizedBox(width: 8.0),
              _buildChoicePill('Crash', _selectedSeverity == 'Crash', () {
                setState(() => _selectedSeverity = 'Crash');
              }, isLight),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ];

      case FeedbackCategory.feature:
        return [
          _buildInputLabel('Category', isLight),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChoicePill('Sync', _selectedFeatureTag == 'Sync', () {
                  setState(() => _selectedFeatureTag = 'Sync');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('Player', _selectedFeatureTag == 'Player', () {
                  setState(() => _selectedFeatureTag = 'Player');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('Social', _selectedFeatureTag == 'Social', () {
                  setState(() => _selectedFeatureTag = 'Social');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('Stats', _selectedFeatureTag == 'Stats', () {
                  setState(() => _selectedFeatureTag = 'Stats');
                }, isLight),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ];

      case FeedbackCategory.improvement:
        return [
          _buildInputLabel('Focus Area', isLight),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChoicePill('Performance', _selectedImprovementArea == 'Performance', () {
                  setState(() => _selectedImprovementArea = 'Performance');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('UI/UX', _selectedImprovementArea == 'UI/UX', () {
                  setState(() => _selectedImprovementArea = 'UI/UX');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('Watchlist', _selectedImprovementArea == 'Watchlist', () {
                  setState(() => _selectedImprovementArea = 'Watchlist');
                }, isLight),
                const SizedBox(width: 8.0),
                _buildChoicePill('Notifications', _selectedImprovementArea == 'Notifications', () {
                  setState(() => _selectedImprovementArea = 'Notifications');
                }, isLight),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ];
    }
  }

  Widget _buildChoicePill(String label, bool isSelected, VoidCallback onTap, bool isLight) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1E1E2C)),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isLight ? AppColors.lightTextSecondary : AppColors.textSecondary),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPickerButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    required bool isLight,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84.0,
        height: 84.0,
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF9FAFB) : const Color(0xFF1B182B),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 24.0),
            if (label != null) ...[
              const SizedBox(height: 4.0),
              Text(
                label,
                style: const TextStyle(color: AppColors.primaryLight, fontSize: 11.0, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, bool isLight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getTitlePlaceholder() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return 'Subtitles out of sync on Season 3';
      case FeedbackCategory.feature:
        return 'Trakt.tv 2-way automatic sync';
      case FeedbackCategory.improvement:
        return 'Smoother episode countdown animations';
    }
  }

  String _getMessagePlaceholder() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return '1. Open Episode 2 in player\n2. Notice subtitles lag 2-3s behind audio';
      case FeedbackCategory.feature:
        return 'Explain how you imagine this feature working and why it would be useful...';
      case FeedbackCategory.improvement:
        return 'What feels sluggish or confusing, and how can we make it better?';
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
