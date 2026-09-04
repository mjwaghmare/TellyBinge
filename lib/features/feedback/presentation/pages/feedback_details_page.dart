import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../data/repositories/feedback_repository_impl.dart';
import '../widgets/feedback_comment_tile.dart';
import '../widgets/feedback_media_preview.dart';
import '../widgets/feedback_pill.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';

class FeedbackDetailsPage extends StatefulWidget {
  final FeedbackItem item;
  final FeedbackRepository? feedbackRepository;
  final AuthRepository? authRepository;

  const FeedbackDetailsPage({
    super.key,
    required this.item,
    this.feedbackRepository,
    this.authRepository,
  });

  @override
  State<FeedbackDetailsPage> createState() => _FeedbackDetailsPageState();
}

class _FeedbackDetailsPageState extends State<FeedbackDetailsPage> {
  late FeedbackItem _item;
  late final FeedbackRepository _repository;
  late final AuthRepository _authRepository;
  UserModel? _currentUserProfile;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late List<Map<String, dynamic>> _comments;
  String _currentUserId = '';
  bool _isVotePending = false;
  bool _isCommentMutationPending = false;
  bool _isCommentSubmitting = false;
  bool _isStatusPending = false;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _attachedCommentImage;
  StreamSubscription<FeedbackItem?>? _feedbackSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _commentsSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool get _isAdmin => _currentUserProfile?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _repository = widget.feedbackRepository ?? FeedbackRepositoryImpl();
    _authRepository = widget.authRepository ?? AuthRepositoryImpl();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _item = widget.item;
    _comments = List<Map<String, dynamic>>.from(_item.comments);

    _subscribeToFeedback();
    _subscribeToComments();
    _loadUserProfile();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final newUid = user?.uid ?? '';
      if (newUid != _currentUserId) {
        setState(() {
          _currentUserId = newUid;
        });
        _subscribeToFeedback();
      }
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authRepository.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUserProfile = profile;
      });
    } catch (_) {}
  }

  void _subscribeToFeedback() {
    _feedbackSubscription?.cancel();
    _feedbackSubscription = _repository
        .getFeedbackStream(
          feedbackId: _item.id,
          currentUserId: _currentUserId,
        )
        .listen((updatedItem) {
      if (!mounted || updatedItem == null) return;
      setState(() {
        _item = updatedItem.copyWith(
          comments: _comments,
          commentCount: _comments.length > updatedItem.commentCount
              ? _comments.length
              : updatedItem.commentCount,
        );
      });
    });
  }

  void _subscribeToComments() {
    _commentsSubscription?.cancel();
    _commentsSubscription = _repository
        .getCommentsStream(_item.id)
        .listen((comments) {
      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(comments);
        _item = _item.copyWith(comments: _comments);
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _feedbackSubscription?.cancel();
    _commentsSubscription?.cancel();
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleUpvote() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _currentUserId = currentUserId;
    if (_isVotePending) return;
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

    final previousItem = _item;
    HapticFeedback.mediumImpact();
    setState(() {
      _isVotePending = true;
      _item = _item.upvoted(currentUserId);
    });
    try {
      await _repository.toggleVote(
        feedbackId: _item.id,
        userId: currentUserId,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _item = previousItem;
          _isVotePending = false;
        });
        AppSnackbar.showError(context, 'Failed to update your vote. Please try again.');
      }
      return;
    }

    if (mounted) setState(() => _isVotePending = false);
  }

  Future<void> _pickCommentImage() async {
    if (_isCommentSubmitting) return;
    HapticFeedback.lightImpact();
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _attachedCommentImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to pick image from gallery. Please check storage permissions.',
        );
      }
    }
  }

  void _removeCommentImage() {
    HapticFeedback.lightImpact();
    setState(() {
      _attachedCommentImage = null;
    });
  }

  Future<void> _addComment() async {
    if (_isCommentMutationPending || _isCommentSubmitting) return;
    final text = _commentController.text.trim();
    final attachedImage = _attachedCommentImage;
    if (text.isEmpty && attachedImage == null) return;

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
      if (attachedImage != null) 'imageUrl': attachedImage.path,
    };

    setState(() {
      _isCommentSubmitting = true;
      _comments.insert(0, newComment);
      _item = _item.copyWith(comments: _comments);
      _commentController.clear();
      _attachedCommentImage = null;
    });

    try {
      await _repository.addComment(
        feedbackId: _item.id,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        text: text,
        localImagePath: attachedImage?.path,
        commentId: commentId,
      );
      if (mounted) setState(() => _isCommentSubmitting = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _comments.removeWhere(
            (c) =>
                c['id'] == commentId ||
                (c['time'] == timeStr && c['userId'] == userId),
          );
          _item = _item.copyWith(comments: _comments);
          _isCommentSubmitting = false;
        });
        AppSnackbar.showError(
          context,
          'Failed to post comment. Please try again.',
        );
      }
    }
  }

  Future<void> _showEditCommentSheet(
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
        backgroundColor: isLight
            ? AppColors.lightSurface
            : AppColors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (sheetCtx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isLight
                            ? AppColors.borderLight
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Comment',
                        style: AppTextStyles.mdBold.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? AppColors.lightSurfaceElevated
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isLight
                            ? AppColors.borderLight
                            : AppColors.borderDark,
                      ),
                    ),
                    child: TextField(
                      controller: editController,
                      maxLines: 4,
                      maxLength: 500,
                      autofocus: true,
                      style: AppTextStyles.sm.copyWith(
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Edit your comment...',
                        hintStyle: AppTextStyles.sm.copyWith(
                          color: isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary,
                        ),
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.all(AppSpacing.sm),
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
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
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
        if (_isCommentMutationPending) return;
        final targetIndex = _comments.indexWhere(
          (c) => commentId.isNotEmpty
              ? c['id'] == commentId
              : (c['time'] == comment['time'] && c['userId'] == comment['userId']),
        );
        if (targetIndex == -1) return;

        final previousComments = List<Map<String, dynamic>>.from(_comments);
        HapticFeedback.lightImpact();
        setState(() {
          _isCommentMutationPending = true;
          _comments[targetIndex] = {
            ..._comments[targetIndex],
            'text': updated,
          };
          _item = _item.copyWith(comments: _comments);
        });

        try {
          await _repository.editComment(
            feedbackId: _item.id,
            commentId: commentId.isNotEmpty
                ? commentId
                : (comment['id']?.toString() ?? ''),
            text: updated,
          );
          if (mounted) {
            setState(() => _isCommentMutationPending = false);
            AppSnackbar.showSuccess(context, 'Comment updated successfully', duration: const Duration(seconds: 2));
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _comments = previousComments;
              _item = _item.copyWith(comments: _comments);
              _isCommentMutationPending = false;
            });
            AppSnackbar.showError(context, 'Failed to update comment. Please try again.');
          }
        }
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
        backgroundColor: isLight
            ? AppColors.lightSurface
            : AppColors.surfaceElevated,
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
      if (_isCommentMutationPending) return;
      final targetIndex = _comments.indexWhere(
        (c) => commentId.isNotEmpty
            ? c['id'] == commentId
            : (c['time'] == comment['time'] && c['userId'] == comment['userId']),
      );
      if (targetIndex == -1) return;

      final previousComments = List<Map<String, dynamic>>.from(_comments);
      HapticFeedback.lightImpact();
      setState(() {
        _isCommentMutationPending = true;
        _comments.removeAt(targetIndex);
        _item = _item.copyWith(comments: _comments);
      });

      try {
        await _repository.deleteComment(
          feedbackId: _item.id,
          commentId: commentId.isNotEmpty
              ? commentId
              : (comment['id']?.toString() ?? ''),
        );
        if (mounted) {
          setState(() => _isCommentMutationPending = false);
          AppSnackbar.showSuccess(context, 'Comment deleted', duration: const Duration(seconds: 2));
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _comments = previousComments;
            _item = _item.copyWith(comments: _comments);
            _isCommentMutationPending = false;
          });
          AppSnackbar.showError(context, 'Failed to delete comment. Please try again.');
        }
      }
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

  Future<void> _updateStatus(FeedbackStatus newStatus) async {
    if (_isStatusPending) return;
    final oldStatus = _item.status;
    if (oldStatus == newStatus) return;

    // Optimistic local update and in-flight guard
    setState(() {
      _isStatusPending = true;
      _item = _item.copyWith(status: newStatus);
    });

    try {
      await _repository.updateFeedbackStatus(
        feedbackId: _item.id,
        status: newStatus,
      );
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Status updated to "${newStatus.label}"',
        );
      }
    } catch (e) {
      if (mounted) {
        // Revert on error
        setState(() {
          _item = _item.copyWith(status: oldStatus);
        });
        AppSnackbar.showError(
          context,
          'Failed to update status: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStatusPending = false;
        });
      }
    }
  }

  Future<void> _showChangeStatusBottomSheet() async {
    final isLight = context.isLight;
    final statuses = FeedbackStatus.genericStatuses;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isLight ? Colors.white : const Color(0xFF161622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Header title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Icon(
                        Icons.published_with_changes_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Feedback Status',
                            style: AppTextStyles.mdBold.copyWith(
                              color: isLight
                                  ? AppColors.lightTextPrimary
                                  : AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            'Current: ${_item.status.label}',
                            style: AppTextStyles.xs.copyWith(
                              color: isLight
                                  ? AppColors.lightTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Divider(
                  color: isLight
                      ? Colors.grey.shade200
                      : Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
                const SizedBox(height: 8.0),

                // Status Options List
                ...statuses.map((status) {
                  final isCurrent = _item.status == status;
                  return InkWell(
                    onTap: _isStatusPending
                        ? null
                        : () async {
                            Navigator.pop(sheetCtx);
                            if (isCurrent) return;
                            HapticFeedback.mediumImpact();
                            await _updateStatus(status);
                          },
                    borderRadius: BorderRadius.circular(14.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isLight
                                ? Colors.grey.shade100
                                : Colors.white.withValues(alpha: 0.05))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14.0),
                        border: isCurrent
                            ? Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          FeedbackPill.status(
                            status: status,
                            isLight: isLight,
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.label,
                                  style: AppTextStyles.smBold.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextPrimary
                                        : AppColors.textPrimary,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  status.description,
                                  style: AppTextStyles.xs.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextSecondary
                                        : AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8.0),
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
    final currentUserId =
        _currentUserProfile?.uid.isNotEmpty == true
            ? _currentUserProfile!.uid
            : (FirebaseAuth.instance.currentUser?.uid ?? _currentUserId);
    final isAdmin = _isAdmin;
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
          if (isOwner || isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                enabled: !_isStatusPending,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                  size: 22,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                color: isLight ? Colors.white : const Color(0xFF1E1E2D),
                elevation: 4,
                onSelected: _isStatusPending
                    ? null
                    : (value) {
                        if (value == 'status') {
                          _showChangeStatusBottomSheet();
                        } else if (value == 'delete') {
                          _showDeleteConfirmationDialog();
                        }
                      },
                itemBuilder: (ctx) => [
                  if (isAdmin)
                    PopupMenuItem<String>(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(
                            Icons.published_with_changes_rounded,
                            size: 20,
                            color: isLight
                                ? AppColors.lightTextPrimary
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Change Status',
                            style: AppTextStyles.smBold.copyWith(
                              color: isLight
                                  ? AppColors.lightTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isOwner || isAdmin)
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Delete Feedback',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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
                            size: 60.0,
                            showAll: true,
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
                        horizontal: 8.0,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? AppColors.lightSurfaceElevated
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: isLight
                              ? AppColors.borderLight
                              : AppColors.borderDark,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${_item.commentCount > 0 ? _item.commentCount : _comments.length}',
                        style: AppTextStyles.xsMedium.copyWith(
                          color: isLight
                              ? AppColors.lightTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 4. Comments List / Empty State
                if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxl,
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(
                                alpha: isLight ? 0.08 : 0.16,
                              ),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: isLight ? 0.2 : 0.25,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No comments yet',
                            style: AppTextStyles.smBold.copyWith(
                              color: isLight
                                  ? AppColors.lightTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Be the first to share your thoughts or join the discussion.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.xs.copyWith(
                              color: isLight
                                  ? AppColors.lightTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._comments.map((comment) {
                    final timeText = _formatCommentTime(comment['time']);
                    final isCommentOwner =
                        currentUserId.isNotEmpty &&
                        comment['userId'] == currentUserId;
                    final isOp = comment['userId'] == _item.userId;

                    return FeedbackCommentTile(
                      key: ValueKey(
                        comment['id'] ??
                            '${comment['userId']}_${comment['time']}',
                      ),
                      comment: comment,
                      isOp: isOp,
                      isOwner: isCommentOwner,
                      formattedTime: timeText,
                      onEdit: () => _showEditCommentSheet(comment),
                      onDelete: () => _showDeleteCommentDialog(comment),
                    );
                  }),
              ],
            ),
          ),

          // 5. Bottom Sticky Comment Input Bar
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.xs,
              top: 6.0,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? (MediaQuery.of(context).padding.bottom - 4.0).clamp(4.0, 34.0)
                  : 6.0,
            ),
            decoration: BoxDecoration(
              color: isLight ? AppColors.lightSurface : AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: isLight
                      ? AppColors.borderLight
                      : AppColors.borderDark,
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.25),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attached Image Thumbnail Preview (Instagram / Slack style)
                if (_attachedCommentImage != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 4.0,
                      bottom: AppSpacing.xs,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: isLight
                                  ? AppColors.borderLight
                                  : AppColors.borderDark,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isLight ? 0.08 : 0.25,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.5),
                            child: Image.file(
                              File(_attachedCommentImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Close / Delete Badge
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: _removeCommentImage,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? Colors.white
                                    : const Color(0xFF2C2C3E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isLight
                                      ? AppColors.borderLight
                                      : Colors.white24,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: isLight
                                    ? AppColors.lightTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Input Row: [Borderless Text Field with clear X] -> [Image Gallery Button] -> [Sliding Send Button]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 1. Text Field Capsule (NO BORDER, reduced roundness, clear X at bottom right)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLight
                              ? AppColors.lightSurfaceElevated
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _commentController,
                          builder: (context, val, _) {
                            final showClear = val.text.isNotEmpty;
                            return Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  style: AppTextStyles.sm.copyWith(
                                    color: isLight
                                        ? AppColors.lightTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add a comment...',
                                    hintStyle: AppTextStyles.sm.copyWith(
                                      color: isLight
                                          ? AppColors.lightTextTertiary
                                          : AppColors.textTertiary,
                                    ),
                                    filled: false,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.only(
                                      left: 14.0,
                                      top: 9.0,
                                      bottom: 9.0,
                                      right: showClear ? 30.0 : 14.0,
                                    ),
                                  ),
                                  onSubmitted: (textVal) {
                                    if (textVal.trim().isNotEmpty ||
                                        _attachedCommentImage != null) {
                                      _addComment();
                                    }
                                  },
                                ),
                                if (showClear)
                                  Positioned(
                                    right: 4.0,
                                    bottom: 3.0,
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _commentController.clear();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.cancel_rounded,
                                          size: 17.0,
                                          color: isLight
                                              ? AppColors.lightTextTertiary
                                              : AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.0),

                    // 2. Image Gallery Button (To the right of field, to the left of send button - NO CIRCLE BG)
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (!_isCommentSubmitting) _pickCommentImage();
                      },
                      splashRadius: 20,
                      padding: const EdgeInsets.all(6.0),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: 'Attach image from gallery',
                      icon: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: isLight
                            ? AppColors.lightTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),

                    // 3. Send Button (Hidden when empty, slides right to left when typing - NO CIRCLE BG)
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _commentController,
                      builder: (context, value, _) {
                        final hasContent = value.text.trim().isNotEmpty ||
                            _attachedCommentImage != null;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          reverseDuration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return ClipRect(
                              child: SizeTransition(
                                axis: Axis.horizontal,
                                alignment: Alignment.centerLeft,
                                sizeFactor: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.6, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: hasContent
                              ? IconButton(
                                  key: const ValueKey('send_comment_button'),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _addComment();
                                  },
                                  splashRadius: 20,
                                  padding: const EdgeInsets.all(6.0),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  icon: _isCommentSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator
                                              .adaptive(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: AppColors.primary,
                                          size: 23,
                                        ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('empty_send_button'),
                                ),
                        );
                      },
                    ),
                  ],
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
        onTap: _isVotePending ? null : _handleUpvote,
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
          child: _isVotePending
              ? const SizedBox(
                  height: 38,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  ),
                )
              : Column(
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
