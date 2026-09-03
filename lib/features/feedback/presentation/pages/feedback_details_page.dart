import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../data/repositories/feedback_repository_impl.dart';
import '../widgets/feedback_media_preview.dart';
import '../widgets/feedback_pill.dart';

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
  final FocusNode _commentFocusNode = FocusNode();
  late List<Map<String, dynamic>> _comments;
  String _currentUserId = '';
  StreamSubscription<List<FeedbackItem>>? _feedbacksSubscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _item = widget.item;
    _comments = List<Map<String, dynamic>>.from(_item.comments);

    _subscribeToFeedbacks();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final newUid = user?.uid ?? '';
      if (newUid != _currentUserId) {
        setState(() {
          _currentUserId = newUid;
        });
        _subscribeToFeedbacks();
      }
    });
  }

  void _subscribeToFeedbacks() {
    _feedbacksSubscription?.cancel();
    _feedbacksSubscription = _repository
        .getFeedbacksStream(currentUserId: _currentUserId)
        .listen((items) {
      if (!mounted) return;
      final index = items.indexWhere((i) => i.id == _item.id);
      if (index != -1) {
        setState(() {
          _item = items[index];
          _comments = List<Map<String, dynamic>>.from(_item.comments);
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _feedbacksSubscription?.cancel();
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleUpvote() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _currentUserId = currentUserId;
    if (currentUserId.isEmpty) {
      AppSnackbar.showInfo(
        context,
        'Please sign in to vote on feedback.',
      );
      return;
    }

    if (_item.userId == currentUserId && _item.isUpvoted) {
      HapticFeedback.lightImpact();
      AppSnackbar.showInfo(
        context,
        'You created this feedback — your upvote is permanent.',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _item = _item.upvoted(currentUserId);
    });
    _repository.toggleVote(
      feedbackId: _item.id,
      userId: currentUserId,
    );
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      AppSnackbar.showInfo(
        context,
        'Please sign in to comment on feedback.',
      );
      return;
    }

    final displayName = user.displayName?.trim();
    final userName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (user.email != null &&
                user.email!.contains('@') &&
                user.email!.split('@').first.trim().isNotEmpty
            ? user.email!.split('@').first.trim()
            : 'PopVerse Fan');
    final userAvatar = user.photoURL ?? '';
    final userId = user.uid;
    _currentUserId = userId;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final commentId = '${userId}_${DateTime.now().microsecondsSinceEpoch}';
    final timeStr = DateTime.now().toIso8601String();
    final newComment = {
      'id': commentId,
      'userId': userId,
      'name': userName,
      'userAvatar': userAvatar,
      'time': timeStr,
      'text': text,
    };

    setState(() {
      _comments.insert(0, newComment);
      _item = _item.copyWith(comments: _comments);
      _commentController.clear();
    });

    try {
      await _repository.addComment(
        feedbackId: _item.id,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        text: text,
        commentId: commentId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _comments.removeWhere(
            (c) =>
                c['id'] == commentId ||
                (c['time'] == timeStr && c['userId'] == userId),
          );
          _item = _item.copyWith(comments: _comments);
        });
        AppSnackbar.showError(
          context,
          'Failed to post comment. Please try again.',
        );
      }
    }
  }  Future<void> _showEditCommentSheet(
    Map<String, dynamic> comment,
  ) async {
    final isLight = context.isLight;
    final editController = TextEditingController(
      text: comment['text'] as String? ?? '',
    );
    final commentId = comment['id']?.toString() ?? '';

    try {
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
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
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
        final targetIndex = _comments.indexWhere(
          (c) => commentId.isNotEmpty
              ? c['id'] == commentId
              : (c['time'] == comment['time'] && c['userId'] == comment['userId']),
        );
        if (targetIndex == -1) return;

        HapticFeedback.lightImpact();
        setState(() {
          _comments[targetIndex] = {
            ..._comments[targetIndex],
            'text': updated,
          };
          _item = _item.copyWith(comments: _comments);
        });

        _repository.updateComments(feedbackId: _item.id, comments: _comments);

        AppSnackbar.showSuccess(
          context,
          'Comment updated successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } finally {
      editController.dispose();
    }
  }

  Future<void> _showDeleteCommentDialog(
    Map<String, dynamic> comment,
  ) async {
    FocusScope.of(context).unfocus();
    _commentFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final isLight = context.isLight;
    final commentId = comment['id']?.toString() ?? '';
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
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(dialogCtx, false);
            },
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
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(dialogCtx, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    _commentFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (confirmed == true) {
      final targetIndex = _comments.indexWhere(
        (c) => commentId.isNotEmpty
            ? c['id'] == commentId
            : (c['time'] == comment['time'] && c['userId'] == comment['userId']),
      );
      if (targetIndex == -1) return;

      HapticFeedback.lightImpact();
      setState(() {
        _comments.removeAt(targetIndex);
        _item = _item.copyWith(comments: _comments);
      });

      _repository.updateComments(feedbackId: _item.id, comments: _comments);

      AppSnackbar.showSuccess(
        context,
        'Comment deleted',
        duration: const Duration(seconds: 2),
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
                            AppSnackbar.showSuccess(
                              context,
                              'Feedback deleted successfully',
                              duration: const Duration(seconds: 2),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isDeleting = false);
                          }
                          if (mounted) {
                            AppSnackbar.showError(
                              context,
                              'Failed to delete feedback: $e',
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? _currentUserId;
    final isOwner = currentUserId.isNotEmpty && _item.userId == currentUserId;

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                // 1. Main Detail Card
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
                      // Top section: Left upvote button + Right content
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Upvote Button
                          _buildUpvoteButton(isLight),
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
                                    if (_item.voteMilestone != null)
                                      FeedbackPill.milestone(
                                        milestone: _item.voteMilestone!,
                                        isLight: isLight,
                                      ),
                                    FeedbackPill.category(
                                      category: _item.category,
                                      isLight: isLight,
                                    ),
                                    if (_item.severity != null &&
                                        _item.severity!.isNotEmpty)
                                      FeedbackPill.severity(
                                        severity: _item.severity!,
                                        isLight: isLight,
                                      ),
                                    FeedbackPill.status(
                                      status: _item.status,
                                      isLight: isLight,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10.0),

                                // Title
                                Text(
                                  _item.title,
                                  style: AppTextStyles.mdBold.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextPrimary
                                        : AppColors.textPrimary,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 8.0),

                                // Full Description
                                Text(
                                  _item.description,
                                  style: AppTextStyles.sm.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextSecondary
                                        : AppColors.textSecondary,
                                    height: 1.45,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 3. Media Gallery (if any)
                      if (_item.media.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.only(left: 60.0),
                          child: FeedbackMediaPreview(
                            media: _item.media,
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

                          // Username
                          Text(
                            _item.userName,
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
                          const SizedBox(width: 8.0),

                          // Timestamp
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
                  ..._comments.map((comment) {
                    final timeText = _formatCommentTime(comment['time']);
                    final isCommentOwner =
                        currentUserId.isNotEmpty &&
                        comment['userId'] == currentUserId;

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
                                         _showEditCommentSheet(comment);
                                       } else if (value == 'delete') {
                                         _showDeleteCommentDialog(comment);
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
                      border: Border.all(
                        color: isLight
                            ? AppColors.borderLight
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
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
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) _addComment();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    final canSubmit = value.text.trim().isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: canSubmit
                            ? const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: canSubmit
                            ? null
                            : (isLight
                                ? Colors.grey[300]
                                : Colors.white.withValues(alpha: 0.1)),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: canSubmit
                              ? Colors.white
                              : (isLight ? Colors.grey[500] : Colors.white38),
                          size: 18,
                        ),
                        onPressed: canSubmit ? _addComment : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // --- SUB WIDGETS ---

  Widget _buildUpvoteButton(bool isLight) {
    final isUpvoted = _item.isUpvoted;

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
        onTap: _handleUpvote,
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
                  _item.formattedVotes,
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
