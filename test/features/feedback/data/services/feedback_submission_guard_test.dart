import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/feedback/data/services/feedback_submission_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enforces and then expires the per-user submission cooldown', () async {
    var now = DateTime(2026, 9, 4, 12);
    final guard = FeedbackSubmissionGuard(
      now: () => now,
      loadPreferences: SharedPreferences.getInstance,
    );

    await guard.recordSubmission('user-1');

    expect(
      await guard.remainingCooldown('user-1'),
      FeedbackSubmissionGuard.cooldown,
    );

    now = now.add(FeedbackSubmissionGuard.cooldown);

    expect(await guard.remainingCooldown('user-1'), isNull);
  });
}
