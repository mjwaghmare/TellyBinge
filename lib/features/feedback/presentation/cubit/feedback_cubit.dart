import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/feedback_item.dart';
import '../../domain/repositories/feedback_repository.dart';
import 'feedback_state.dart';

class FeedbackCubit extends Cubit<FeedbackState> {
  final FeedbackRepository feedbackRepository;
  StreamSubscription<List<FeedbackItem>>? _feedbackSubscription;

  FeedbackCubit({required this.feedbackRepository}) : super(FeedbackInitial());

  void loadFeedbacks({String? currentUserId}) {
    emit(FeedbackLoading());
    _feedbackSubscription?.cancel();

    _feedbackSubscription = feedbackRepository
        .getFeedbacksStream(currentUserId: currentUserId)
        .listen(
          (items) {
            emit(FeedbackLoaded(items: items));
          },
          onError: (error) {
            emit(FeedbackError(error.toString()));
          },
        );
  }

  Future<bool> submitFeedback({
    required String title,
    required String description,
    required FeedbackCategory category,
    required String? severity,
    required List<String> localMediaPaths,
    required String userId,
    required String userName,
    required String userAvatar,
    required String appVersion,
  }) async {
    final currentState = state;
    if (currentState is FeedbackLoaded) {
      emit(currentState.copyWith(isSubmitting: true, submitError: null));
    }

    try {
      await feedbackRepository.submitFeedback(
        title: title,
        description: description,
        category: category,
        severity: severity,
        localMediaPaths: localMediaPaths,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        appVersion: appVersion,
      );

      if (state is FeedbackLoaded) {
        emit((state as FeedbackLoaded).copyWith(isSubmitting: false));
      }
      return true;
    } catch (e) {
      if (state is FeedbackLoaded) {
        emit(
          (state as FeedbackLoaded).copyWith(
            isSubmitting: false,
            submitError: e.toString(),
          ),
        );
      }
      return false;
    }
  }

  Future<void> toggleVote({
    required FeedbackItem item,
    required String userId,
    required bool isUpvote,
  }) async {
    if (userId.isEmpty) return;

    // Optimistic UI update
    if (state is FeedbackLoaded) {
      final currentLoaded = state as FeedbackLoaded;
      final updatedList = currentLoaded.items.map((i) {
        if (i.id == item.id) {
          return isUpvote ? i.upvoted(userId) : i.downvoted(userId);
        }
        return i;
      }).toList();

      emit(currentLoaded.copyWith(items: updatedList));
    }

    try {
      await feedbackRepository.toggleVote(
        feedbackId: item.id,
        userId: userId,
        isUpvote: isUpvote,
      );
    } catch (_) {
      // Stream subscription will revert or reflect accurate state from Firestore
    }
  }

  Future<void> addComment({
    required String feedbackId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String text,
  }) async {
    try {
      await feedbackRepository.addComment(
        feedbackId: feedbackId,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        text: text,
      );
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _feedbackSubscription?.cancel();
    return super.close();
  }
}
