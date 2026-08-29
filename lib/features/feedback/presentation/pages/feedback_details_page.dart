import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';

class FeedbackDetailsPage extends StatefulWidget {
  final FeedbackItem item;
  final ValueChanged<FeedbackItem>? onUpdate;

  const FeedbackDetailsPage({
    super.key,
    required this.item,
    this.onUpdate,
  });

  @override
  State<FeedbackDetailsPage> createState() => _FeedbackDetailsPageState();
}

class _FeedbackDetailsPageState extends State<FeedbackDetailsPage> {
  late FeedbackItem _item;
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, String>> _comments = [
    {
      'name': 'Dany Cinge',
      'time': '2h ago',
      'text': 'Agreed, seeing this too. Thanks for highlighting!',
    },
    {
      'name': 'Daba Yoman',
      'time': '1d ago',
      'text': 'Thought it was just me! Looking forward to the fix.',
    },
    {
      'name': 'Adan Damon',
      'time': '1d ago',
      'text': 'Is this happening on both WiFi and cellular data?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleUpvote() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_item.isUpvoted) {
        _item = _item.copyWith(
          votes: (_item.votes - 1).clamp(0, 99999),
          isUpvoted: false,
        );
      } else {
        final diff = _item.isDownvoted ? 2 : 1;
        _item = _item.copyWith(
          votes: _item.votes + diff,
          isUpvoted: true,
          isDownvoted: false,
        );
      }
    });
    widget.onUpdate?.call(_item);
  }

  void _handleDownvote() {
    if (_item.votes <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_item.isDownvoted) {
        _item = _item.copyWith(
          votes: _item.votes + 1,
          isDownvoted: false,
        );
      } else {
        final diff = _item.isUpvoted ? 2 : 1;
        _item = _item.copyWith(
          votes: (_item.votes - diff).clamp(0, 99999),
          isDownvoted: true,
          isUpvoted: false,
        );
      }
    });
    widget.onUpdate?.call(_item);
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _comments.insert(0, {
        'name': 'You',
        'time': 'Just now',
        'text': text,
      });
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final canDownvote = _item.votes > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context, _item),
        ),
        title: Text(
          'Feedback Details',
          style: AppTextStyles.lg.copyWith(
            color: isLight
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: _buildStatusPill(_item.status, isLight),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // 1. Main Detail Card with full description
                Container(
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Upvote Capsule + Category Pill + Submitter Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVoteCapsule(isLight, canDownvote),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildCategoryPill(_item.category, isLight),
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
                                        _item.appVersion,
                                        style: AppTextStyles.xs.copyWith(
                                          color: isLight
                                              ? AppColors.lightTextSecondary
                                              : AppColors.textSecondary,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10.0),
                                // Title
                                Text(
                                  _item.title,
                                  style: AppTextStyles.lg.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextPrimary
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.0,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Full Description (Unrestricted length)
                      Text(
                        _item.description,
                        style: AppTextStyles.md.copyWith(
                          color: isLight
                              ? AppColors.lightTextSecondary
                              : AppColors.textSecondary,
                          height: 1.5,
                          fontSize: 14.5,
                        ),
                      ),

                      // Attached Media Gallery
                      if (_item.mediaUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'ATTACHED MEDIA (${_item.mediaUrls.length})',
                          style: TextStyle(
                            color: isLight
                                ? AppColors.lightTextTertiary
                                : const Color(0xFF8E8E93),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        SizedBox(
                          height: 140.0,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _item.mediaUrls.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10.0),
                            itemBuilder: (context, index) {
                              final url = _item.mediaUrls[index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  width: 220.0,
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
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                      Icons.image_outlined,
                                      color: AppColors.textTertiary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              );
                            },
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

                      // Author Row
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _item.userName.isNotEmpty
                                    ? _item.userName[0].toUpperCase()
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
                          Text(
                            'Submitted by ${_item.userName}',
                            style: AppTextStyles.xsMedium.copyWith(
                              color: isLight
                                  ? AppColors.lightTextPrimary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _item.timeAgo,
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

                const SizedBox(height: AppSpacing.md),

                // 2. Official Team Response Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : const Color(0xFF1E1A30),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'Official Response',
                            style: AppTextStyles.smBold.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'PopVerse Team',
                            style: AppTextStyles.xs.copyWith(
                              color: isLight
                                  ? AppColors.lightTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Thanks for reporting this! Our team has identified the reproduction steps and a patch is scheduled for the next release.',
                        style: AppTextStyles.sm.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // 3. Discussion Header
                Row(
                  children: [
                    Text(
                      'Discussion',
                      style: AppTextStyles.mdBold.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? Colors.grey[200]
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        '${_comments.length}',
                        style: AppTextStyles.xsMedium.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 4. Comments List
                ..._comments.map((comment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isLight
                            ? AppColors.borderLight
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment['name']!,
                              style: AppTextStyles.smBold.copyWith(
                                color: isLight
                                    ? AppColors.lightTextPrimary
                                    : AppColors.textPrimary,
                                fontSize: 13.0,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              comment['time']!,
                              style: AppTextStyles.xs.copyWith(
                                color: isLight
                                    ? AppColors.lightTextTertiary
                                    : const Color(0xFF8E8E93),
                                fontSize: 11.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          comment['text']!,
                          style: AppTextStyles.sm.copyWith(
                            color: isLight
                                ? AppColors.lightTextSecondary
                                : AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // 5. Bottom Sticky Comment Input Bar
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF161622),
              border: Border(
                top: BorderSide(
                  color: isLight
                      ? AppColors.borderLight
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 14.0,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary,
                          fontSize: 14.0,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _addComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB WIDGETS ---

  Widget _buildVoteCapsule(bool isLight, bool canDownvote) {
    final hasVoted = _item.isUpvoted;

    return Container(
      width: 48.0,
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: hasVoted
            ? AppColors.primary.withValues(alpha: 0.15)
            : (isLight ? const Color(0xFFF3F4F6) : const Color(0xFF1E1E2C)),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: hasVoted
              ? AppColors.primary
              : (isLight
                  ? AppColors.borderLight
                  : Colors.white.withValues(alpha: 0.06)),
          width: hasVoted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleUpvote,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: hasVoted
                      ? AppColors.primary
                      : (isLight ? AppColors.lightTextPrimary : Colors.white),
                  size: 22,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              '${_item.votes}',
              style: AppTextStyles.smBold.copyWith(
                color: hasVoted
                    ? AppColors.primary
                    : (isLight ? AppColors.lightTextPrimary : Colors.white),
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canDownvote ? _handleDownvote : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: canDownvote
                      ? (isLight ? AppColors.lightTextSecondary : Colors.white70)
                      : (isLight ? Colors.grey[300] : Colors.white24),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(FeedbackCategory category, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: category.backgroundColor(isLight),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: category.textColor(isLight),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildStatusPill(FeedbackStatus status, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: status.backgroundColor(isLight),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.textColor(isLight),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
