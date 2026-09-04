import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/feedback/domain/models/feedback_item.dart';

void main() {
  group('FeedbackItem.fromMap', () {
    test('parses a Firestore-shaped feedback document and voter state', () {
      final item = FeedbackItem.fromMap(
        {
          'title': 'Offline downloads fail',
          'description': 'A download never completes.',
          'category': 'bug',
          'status': 'underReview',
          'votes': 7,
          'media': ['https://cdn.example.com/screenshot.jpg', ''],
          'severity': 'Major',
          'comments': [
            {
              'id': 'comment-1',
              'userId': 'user-2',
              'name': 'Taylor',
              'text': 'I can reproduce this.',
              'time': '2026-09-04T10:00:00.000Z',
            },
          ],
          'userId': 'author-1',
          'userName': 'Morgan',
          'userAvatar': 'https://cdn.example.com/avatar.jpg',
          'appVersion': 'v1.2.3+4',
          'createdAt': '2026-09-04T09:00:00.000Z',
          'upvotedUserIds': ['user-1', 'user-2'],
        },
        'feedback-1',
        'user-1',
      );

      expect(item.id, 'feedback-1');
      expect(item.category, FeedbackCategory.bug);
      expect(item.status, FeedbackStatus.underReview);
      expect(item.votes, 7);
      expect(item.media, const [
        FeedbackMedia(path: 'https://cdn.example.com/screenshot.jpg'),
      ]);
      expect(item.comments, hasLength(1));
      expect(item.isUpvoted, isTrue);
      expect(item.createdAt, DateTime.parse('2026-09-04T09:00:00.000Z'));
    });

    test('uses safe enum fallbacks for legacy or invalid documents', () {
      final item = FeedbackItem.fromMap({
        'category': 'request',
        'status': 'shipped',
      }, 'feedback-1');

      expect(item.category, FeedbackCategory.bug);
      expect(item.status, FeedbackStatus.open);
      expect(item.media, isEmpty);
      expect(item.comments, isEmpty);
    });

    test('parses closed status correctly and defines genericStatuses', () {
      final item = FeedbackItem.fromMap({
        'category': 'bug',
        'status': 'closed',
      }, 'feedback-2');

      expect(item.status, FeedbackStatus.closed);
      expect(FeedbackStatus.genericStatuses, [
        FeedbackStatus.open,
        FeedbackStatus.inProgress,
        FeedbackStatus.resolved,
        FeedbackStatus.closed,
      ]);
    });
  });

  group('FeedbackItem.upvoted', () {
    const item = FeedbackItem(
      id: 'feedback-1',
      title: 'Title',
      description: 'Description',
      category: FeedbackCategory.feature,
      status: FeedbackStatus.open,
      votes: 1,
      userName: 'Morgan',
      userAvatar: '',
      appVersion: 'v1.0.0',
      upvotedUserIds: ['author-1'],
    );

    test('adds the current user and increments the vote count', () {
      final updated = item.upvoted('user-2');

      expect(updated.votes, 2);
      expect(updated.isUpvoted, isTrue);
      expect(updated.upvotedUserIds, ['author-1', 'user-2']);
    });

    test('removes an existing vote without producing a negative count', () {
      final alreadyUpvoted = item.copyWith(
        votes: 0,
        upvotedUserIds: ['author-1', 'user-2'],
        isUpvoted: true,
      );

      final updated = alreadyUpvoted.upvoted('user-2');

      expect(updated.votes, 0);
      expect(updated.isUpvoted, isFalse);
      expect(updated.upvotedUserIds, ['author-1']);
    });
  });
}
