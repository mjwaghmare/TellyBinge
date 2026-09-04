import '../models/feedback_item.dart';

abstract class FeedbackRepository {
  /// Streams feedback items in real-time with optional limit and category filtering
  Stream<List<FeedbackItem>> getFeedbacksStream({
    String? currentUserId,
    int limit = 50,
    FeedbackCategory? category,
  });

  /// Streams a single feedback item in real-time by document ID
  Stream<FeedbackItem?> getFeedbackStream({
    required String feedbackId,
    String? currentUserId,
  });

  /// Submits new feedback, uploading any attached media first
  Future<FeedbackItem> submitFeedback({
    required String title,
    required String description,
    required FeedbackCategory category,
    required String? severity,
    required List<String> localMediaPaths,
    required String userId,
    required String userName,
    required String userAvatar,
    required String appVersion,
  });

  /// Toggles upvote for a specific user
  Future<void> toggleVote({
    required String feedbackId,
    required String userId,
  });

  /// Streams real-time comments for a feedback item (bounded by limit for performance and scale)
  Stream<List<Map<String, dynamic>>> getCommentsStream(
    String feedbackId, {
    int limit = 50,
  });

  /// Adds a comment to a feedback item
  Future<void> addComment({
    required String feedbackId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String text,
    String? localImagePath,
    String? imageUrl,
    String? commentId,
  });

  /// Edits an existing comment (author or admin only)
  Future<void> editComment({
    required String feedbackId,
    required String commentId,
    required String text,
  });

  /// Deletes a comment (author or admin only)
  Future<void> deleteComment({
    required String feedbackId,
    required String commentId,
  });

  /// Updates comments list for a feedback item (e.g. after edit or delete)
  Future<void> updateComments({
    required String feedbackId,
    required List<Map<String, dynamic>> comments,
  });

  /// Deletes a feedback item (for author or admin)
  Future<void> deleteFeedback(String feedbackId);

  /// Updates feedback status (admin only)
  Future<void> updateFeedbackStatus({
    required String feedbackId,
    required FeedbackStatus status,
  });
}
