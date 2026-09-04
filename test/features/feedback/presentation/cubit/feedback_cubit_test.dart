import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/feedback/domain/models/feedback_item.dart';
import 'package:popverse/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:popverse/features/feedback/presentation/cubit/feedback_cubit.dart';
import 'package:popverse/features/feedback/presentation/cubit/feedback_state.dart';

class FakeFeedbackRepository implements FeedbackRepository {
  final StreamController<List<FeedbackItem>> _controller =
      StreamController<List<FeedbackItem>>.broadcast();
  Object? submitError;
  Object? toggleVoteError;
  int submitCalls = 0;

  void emit(List<FeedbackItem> items) => _controller.add(items);

  @override
  Stream<List<FeedbackItem>> getFeedbacksStream({
    String? currentUserId,
    int limit = 50,
    FeedbackCategory? category,
  }) => _controller.stream;

  @override
  Stream<FeedbackItem?> getFeedbackStream({
    required String feedbackId,
    String? currentUserId,
  }) {
    return Stream.value(feedbackItem);
  }

  @override
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
  }) async {
    submitCalls++;
    if (submitError != null) throw submitError!;
    return feedbackItem;
  }

  @override
  Future<void> toggleVote({
    required String feedbackId,
    required String userId,
  }) async {
    if (toggleVoteError != null) throw toggleVoteError!;
  }

  @override
  Stream<List<Map<String, dynamic>>> getCommentsStream(
    String feedbackId, {
    int limit = 50,
  }) {
    return Stream.value(const []);
  }

  @override
  Future<void> addComment({
    required String feedbackId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String text,
    String? commentId,
  }) async {}

  @override
  Future<void> editComment({
    required String feedbackId,
    required String commentId,
    required String text,
  }) async {}

  @override
  Future<void> deleteComment({
    required String feedbackId,
    required String commentId,
  }) async {}

  @override
  Future<void> updateComments({
    required String feedbackId,
    required List<Map<String, dynamic>> comments,
  }) async {}

  @override
  Future<void> deleteFeedback(String feedbackId) async {}

  Future<void> dispose() => _controller.close();
}

const feedbackItem = FeedbackItem(
  id: 'feedback-1',
  title: 'Title',
  description: 'Description',
  category: FeedbackCategory.bug,
  status: FeedbackStatus.open,
  votes: 1,
  userId: 'author-1',
  userName: 'Morgan',
  userAvatar: '',
  appVersion: 'v1.0.0',
  upvotedUserIds: ['author-1'],
);

void main() {
  late FakeFeedbackRepository repository;
  late FeedbackCubit cubit;

  setUp(() {
    repository = FakeFeedbackRepository();
    cubit = FeedbackCubit(feedbackRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
  });

  group('FeedbackCubit', () {
    test('loads streamed feedback into FeedbackLoaded', () async {
      cubit.loadFeedbacks(currentUserId: 'user-1');
      repository.emit([feedbackItem]);

      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<FeedbackLoaded>());
      expect((cubit.state as FeedbackLoaded).items, [feedbackItem]);
    });

    test('returns false and retains the submission error', () async {
      cubit.loadFeedbacks();
      repository.emit([feedbackItem]);
      await Future<void>.delayed(Duration.zero);
      repository.submitError = StateError('Upload failed');

      final submitted = await cubit.submitFeedback(
        title: 'Title',
        description: 'Description',
        category: FeedbackCategory.bug,
        severity: 'Major',
        localMediaPaths: const [],
        userId: 'user-1',
        userName: 'Taylor',
        userAvatar: '',
        appVersion: 'v1.0.0',
      );

      expect(submitted, isFalse);
      expect(repository.submitCalls, 1);
      expect(cubit.state, isA<FeedbackLoaded>());
      expect(
        (cubit.state as FeedbackLoaded).submitError,
        contains('Upload failed'),
      );
    });

    test('restores the previous vote when the mutation fails', () async {
      cubit.loadFeedbacks(currentUserId: 'user-2');
      repository.emit([feedbackItem]);
      await Future<void>.delayed(Duration.zero);
      repository.toggleVoteError = StateError('Permission denied');

      await cubit.toggleVote(item: feedbackItem, userId: 'user-2');

      final state = cubit.state as FeedbackLoaded;
      expect(state.items.single.votes, feedbackItem.votes);
      expect(state.items.single.isUpvoted, feedbackItem.isUpvoted);
    });
  });
}
