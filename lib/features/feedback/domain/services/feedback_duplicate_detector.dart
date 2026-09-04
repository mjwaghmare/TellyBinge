import '../models/feedback_item.dart';

class FeedbackDuplicateDetector {
  const FeedbackDuplicateDetector._();

  static FeedbackItem? findDuplicate({
    required Iterable<FeedbackItem> existingItems,
    required String title,
    required String description,
    required FeedbackCategory category,
  }) {
    final normalizedTitle = _normalize(title);
    final normalizedDescription = _normalize(description);

    for (final item in existingItems) {
      if (item.category == category &&
          _normalize(item.title) == normalizedTitle &&
          _normalize(item.description) == normalizedDescription) {
        return item;
      }
    }
    return null;
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
