import '../models/achievement.dart';

abstract class AchievementsRepository {
  /// Fetches all unlocked achievements for [uid].
  ///
  /// Returns a map where the key is `${achievementId}_${tierName}` and the
  /// value is the [DateTime] when it was unlocked.
  Future<Map<String, DateTime>> getUnlockedAchievements(String uid);

  /// Persists a batch of newly unlocked achievements for [uid].
  Future<void> saveUnlockedAchievements(
    String uid,
    List<Achievement> achievements,
  );

  /// Streams the set of unlocked achievements for [uid].
  Stream<Map<String, DateTime>> watchUnlockedAchievements(String uid);
}
