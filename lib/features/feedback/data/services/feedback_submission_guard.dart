import 'package:shared_preferences/shared_preferences.dart';

class FeedbackSubmissionGuard {
  static const Duration cooldown = Duration(seconds: 30);
  static const String _keyPrefix = 'feedback_submission_at_';

  final Future<SharedPreferences> Function() _loadPreferences;
  final DateTime Function() _now;

  FeedbackSubmissionGuard({
    Future<SharedPreferences> Function()? loadPreferences,
    DateTime Function()? now,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  Future<Duration?> remainingCooldown(String userId) async {
    if (userId.isEmpty) return null;

    final preferences = await _loadPreferences();
    final submittedAt = preferences.getInt('$_keyPrefix$userId');
    if (submittedAt == null) return null;

    final elapsed = _now().difference(
      DateTime.fromMillisecondsSinceEpoch(submittedAt),
    );
    final remaining = cooldown - elapsed;
    return remaining > Duration.zero ? remaining : null;
  }

  Future<void> recordSubmission(String userId) async {
    if (userId.isEmpty) return;
    final preferences = await _loadPreferences();
    await preferences.setInt(
      '$_keyPrefix$userId',
      _now().millisecondsSinceEpoch,
    );
  }
}
