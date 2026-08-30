import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../data/repositories/feedback_repository_impl.dart';

class FeedbackDetailsPage extends StatefulWidget {
  final FeedbackItem item;
  final FeedbackRepository? feedbackRepository;

  const FeedbackDetailsPage({
    super.key,
    required this.item,
    this.feedbackRepository,
  });

  @override
  State<FeedbackDetailsPage> createState() => _FeedbackDetailsPageState();
}

class _FeedbackDetailsPageState extends State<FeedbackDetailsPage> {
  late FeedbackItem _item;
  late final FeedbackRepository _repository;
  final TextEditingController _commentController = TextEditingController();
  late List<Map<String, dynamic>> _comments;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _item = widget.item;
    _comments = List<Map<String, dynamic>>.from(_item.comments);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _handleUpvote() {
    HapticFeedback.lightImpact();
    setState(() {
      _item = _item.upvoted(_currentUserId);
    });
    if (_currentUserId.isNotEmpty) {
      _repository.toggleVote(
        feedbackId: _item.id,
        userId: _currentUserId,
        isUpvote: true,
      );
    }
  }

  void _handleDownvote() {
    HapticFeedback.lightImpact();
    setState(() {
      _item = _item.downvoted(_currentUserId);
    });
    if (_currentUserId.isNotEmpty) {
      _repository.toggleVote(
        feedbackId: _item.id,
        userId: _currentUserId,
        isUpvote: false,
      );
    }
  }

  void _addComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final userName =
        user?.displayName ??
        (user?.email != null && user!.email!.contains('@')
            ? user.email!.split('@').first
            : 'PopVerse Fan');
    final userAvatar = user?.photoURL ?? '';
    final userId = user?.uid ?? _currentUserId;

    HapticFeedback.lightImpact();
    setState(() {
      final newComment = {
        'userId': userId,
        'name': userName,
        'userAvatar': userAvatar,
        'time': 'Just now',
        'text': text,
      };
      _comments.insert(0, newComment);
      _item = _item.copyWith(comments: _comments);
      _commentController.clear();
    });

    _repository.addComment(
      feedbackId: _item.id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      text: text,
    );
  }

  Future<void> _showEditCommentSheet(
    int index,
    Map<String, dynamic> comment,
  ) async {
    final isLight = context.isLight;
    final editController = TextEditingController(
      text: comment['text'] as String? ?? '',
    );

    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isLight ? Colors.white : const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Comment',
                      style: AppTextStyles.mdBold.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                        fontSize: 17.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF9FAFB)
                        : const Color(0xFF1B182B),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isLight
                          ? AppColors.borderLight
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: editController,
                    maxLines: 4,
                    maxLength: 500,
                    autofocus: true,
                    style: TextStyle(
                      color: isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Edit your comment...',
                      hintStyle: TextStyle(
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                        fontSize: 13.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final newText = editController.text.trim();
                      if (newText.isNotEmpty) {
                        Navigator.pop(sheetCtx, newText);
                      }
                    },
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );

    if (updated != null && updated.isNotEmpty && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _comments[index] = {...comment, 'text': updated};
        _item = _item.copyWith(comments: _comments);
      });

      _repository.updateComments(feedbackId: _item.id, comments: _comments);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showDeleteCommentDialog(int index) async {
    final isLight = context.isLight;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isLight ? Colors.white : const Color(0xFF161622),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Delete Comment',
          style: AppTextStyles.mdBold.copyWith(
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: AppTextStyles.sm.copyWith(
            color: isLight
                ? AppColors.lightTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _comments.removeAt(index);
        _item = _item.copyWith(comments: _comments);
      });

      _repository.updateComments(feedbackId: _item.id, comments: _comments);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatCommentTime(dynamic rawTime) {
    if (rawTime == null) return 'Just now';
    if (rawTime is String) {
      if (rawTime == 'Just now') return rawTime;
      final parsed = DateTime.tryParse(rawTime);
      if (parsed != null) {
        final diff = DateTime.now().difference(parsed);
        if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
        if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
        if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
        if (diff.inDays > 0) return '${diff.inDays}d ago';
        if (diff.inHours > 0) return '${diff.inHours}h ago';
        if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
        return 'Just now';
      }
      return rawTime;
    }
    return 'Just now';
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final isLight = context.isLight;
    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialogState) {
          return AlertDialog(
            backgroundColor: isLight ? Colors.white : const Color(0xFF161622),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            title: Text(
              'Delete Feedback',
              style: AppTextStyles.mdBold.copyWith(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            content: Text(
              'Are you sure you want to delete this feedback? All media and comments will also be permanently removed.',
              style: AppTextStyles.sm.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.error.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  elevation: 0,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        HapticFeedback.mediumImpact();
                        try {
                          await _repository.deleteFeedback(_item.id);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Feedback deleted successfully'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isDeleting = false);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete feedback: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          backgroundColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final canDownvote = _item.votes > 0 || _item.isDownvoted;
    final canSubmitComment = _commentController.text.trim().isNotEmpty;
    final isOwner = _currentUserId.isNotEmpty && _item.userId == _currentUserId;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context, _item),
        ),
        title: Text(
          'Feedback Details',
          style: AppTextStyles.lg.copyWith(
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          if (isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _showDeleteConfirmationDialog,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
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
                                    if (_item.severity != null &&
                                        _item.severity!.isNotEmpty) ...[
                                      const SizedBox(width: 6.0),
                                      _buildSeverityPill(
                                        _item.severity!,
                                        isLight,
                                      ),
                                    ],
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
                                            : Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          10.0,
                                        ),
                                        border: Border.all(
                                          color: isLight
                                              ? AppColors.borderLight
                                              : Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
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
                                const SizedBox(height: 8.0),
                                _buildStatusPill(_item.status, isLight),
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
                      if (_item.media.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'ATTACHED MEDIA (${_item.media.length})',
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
                            itemCount: _item.media.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10.0),
                            itemBuilder: (context, index) {
                              final mediaItem = _item.media[index];
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
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                    ),
                                  ),
                                  child: mediaItem.isLocal
                                      ? Image.file(
                                          File(mediaItem.path),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.image_outlined,
                                                    color:
                                                        AppColors.textTertiary,
                                                    size: 28,
                                                  ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: mediaItem.path,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
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
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
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

                // 2. Official Team Response Card (Conditional on _item.officialResponse)
                if (_item.officialResponse != null &&
                    _item.officialResponse!.isNotEmpty) ...[
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
                          _item.officialResponse!,
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
                ],

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
                if (_comments.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                      horizontal: AppSpacing.md,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No comments yet. Start the discussion below!',
                      style: AppTextStyles.sm.copyWith(
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                  )
                else
                  ..._comments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final comment = entry.value;
                    final timeText = _formatCommentTime(comment['time']);
                    final isCommentOwner =
                        _currentUserId.isNotEmpty &&
                        comment['userId'] == _currentUserId;

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
                                comment['name'] ?? 'PopVerse User',
                                style: AppTextStyles.smBold.copyWith(
                                  color: isLight
                                      ? AppColors.lightTextPrimary
                                      : AppColors.textPrimary,
                                  fontSize: 13.0,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                timeText,
                                style: AppTextStyles.xs.copyWith(
                                  color: isLight
                                      ? AppColors.lightTextTertiary
                                      : const Color(0xFF8E8E93),
                                  fontSize: 11.0,
                                ),
                              ),
                              if (isCommentOwner) ...[
                                const SizedBox(width: 4.0),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    iconSize: 18,
                                    icon: Icon(
                                      Icons.more_horiz_rounded,
                                      color: isLight
                                          ? AppColors.lightTextTertiary
                                          : AppColors.textTertiary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    color: isLight
                                        ? Colors.white
                                        : const Color(0xFF1E1E2C),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditCommentSheet(index, comment);
                                      } else if (value == 'delete') {
                                        _showDeleteCommentDialog(index);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        height: 38,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: isLight
                                                  ? AppColors.lightTextPrimary
                                                  : AppColors.textPrimary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: isLight
                                                    ? AppColors.lightTextPrimary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        height: 38,
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: AppColors.error,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            comment['text'] ?? '',
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
                      onChanged: (_) => setState(() {}),
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
                      onSubmitted: (_) {
                        if (canSubmitComment) _addComment();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: canSubmitComment
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canSubmitComment
                        ? null
                        : (isLight
                              ? Colors.grey[300]
                              : Colors.white.withValues(alpha: 0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: canSubmitComment
                          ? Colors.white
                          : (isLight ? Colors.grey[500] : Colors.white38),
                      size: 18,
                    ),
                    onPressed: canSubmitComment ? _addComment : null,
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
    final hasVoted = _item.isUpvoted || _item.isDownvoted;

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
                  color: _item.isUpvoted
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
                  color: _item.isDownvoted
                      ? AppColors.primary
                      : (canDownvote
                            ? (isLight
                                  ? AppColors.lightTextSecondary
                                  : Colors.white70)
                            : (isLight ? Colors.grey[300] : Colors.white24)),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityPill(String severity, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppColors.error.withValues(alpha: isLight ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: isLight ? AppColors.error : const Color(0xFFFF6B6B),
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
        ),
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
