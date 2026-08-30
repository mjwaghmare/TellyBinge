import '../models/feedback_item.dart';

abstract class FeedbackRepository {
  /// Streams all feedback items in real-time, optionally evaluated against current user ID for votes
  Stream<List<FeedbackItem>> getFeedbacksStream({String? currentUserId});

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

  /// Toggles upvote or downvote for a specific user
  Future<void> toggleVote({
    required String feedbackId,
    required String userId,
    required bool isUpvote,
  });

  /// Adds a comment to a feedback item
  Future<void> addComment({
    required String feedbackId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String text,
  });

  /// Updates comments list for a feedback item (e.g. after edit or delete)
  Future<void> updateComments({
    required String feedbackId,
    required List<Map<String, dynamic>> comments,
  });

  /// Deletes a feedback item (for author or admin)
  Future<void> deleteFeedback(String feedbackId);
}
