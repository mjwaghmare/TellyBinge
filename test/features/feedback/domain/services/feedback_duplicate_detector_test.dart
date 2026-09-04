import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/feedback/domain/models/feedback_item.dart';
import 'package:popverse/features/feedback/domain/services/feedback_duplicate_detector.dart';

const _item = FeedbackItem(
  id: 'feedback-1',
  title: 'Offline downloads fail',
  description: 'Downloads never complete.',
  category: FeedbackCategory.bug,
  status: FeedbackStatus.open,
  votes: 1,
  userName: 'Morgan',
  userAvatar: '',
  appVersion: 'v1.0.0',
);

void main() {
  group('FeedbackDuplicateDetector', () {
    test('finds equal content despite casing and whitespace differences', () {
      final duplicate = FeedbackDuplicateDetector.findDuplicate(
        existingItems: const [_item],
        title: '  OFFLINE   downloads fail ',
        description: 'Downloads  never complete.',
        category: FeedbackCategory.bug,
      );

      expect(duplicate, _item);
    });

    test('does not block feedback in another category', () {
      final duplicate = FeedbackDuplicateDetector.findDuplicate(
        existingItems: const [_item],
        title: _item.title,
        description: _item.description,
        category: FeedbackCategory.feature,
      );

      expect(duplicate, isNull);
    });
  });
}
