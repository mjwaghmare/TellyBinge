import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/domain/models/achievement.dart';
import 'package:popverse/features/profile/domain/services/achievements_service.dart';

void main() {
  group('AchievementsService', () {
    test('first_step is unlocked when 1 item is watched', () {
      final results0 = AchievementsService.evaluate(movies: [], shows: []);
      final firstStep0 = results0.firstWhere((a) => a.id == 'first_step');
      expect(firstStep0.isUnlocked, false);
      expect(firstStep0.currentValue, 0);
      expect(firstStep0.targetValue, 1);

      final results1 = AchievementsService.evaluate(
        movies: [
          {'isWatched': true, 'watchedAt': '2026-08-28T12:00:00.000Z'},
        ],
        shows: [],
      );
      final firstStep1 = results1.firstWhere((a) => a.id == 'first_step');
      expect(firstStep1.isUnlocked, true);
      expect(firstStep1.currentValue, 1);
      expect(firstStep1.targetValue, 1);
      expect(firstStep1.tier, AchievementTier.none);
    });

    test('weekend_warrior combines Saturday and Sunday counts', () {
      // Saturday 2026-08-22 and Sunday 2026-08-23
      final results = AchievementsService.evaluate(
        movies: [
          {'isWatched': true, 'watchedAt': '2026-08-22T10:00:00.000Z'},
          {'isWatched': true, 'watchedAt': '2026-08-22T15:00:00.000Z'},
          {'isWatched': true, 'watchedAt': '2026-08-23T12:00:00.000Z'},
        ],
        shows: [],
      );
      final weekend = results.firstWhere((a) => a.id == 'weekend_warrior');
      expect(weekend.isUnlocked, true);
      expect(weekend.currentValue, 1);

      // Episode weekend combining Sat + Sun to reach 10
      final epResults = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'watchedEpisodes': List.generate(6, (i) => 'S01E0$i'),
            'episodeWatchedDates': {
              for (var i = 0; i < 6; i++) 'S01E0$i': '2026-08-22T10:00:00.000Z',
            },
          },
          {
            'watchedEpisodes': List.generate(4, (i) => 'S02E0$i'),
            'episodeWatchedDates': {
              for (var i = 0; i < 4; i++) 'S02E0$i': '2026-08-23T10:00:00.000Z',
            },
          },
        ],
      );
      final epWeekend = epResults.firstWhere((a) => a.id == 'weekend_warrior');
      expect(epWeekend.isUnlocked, true);
    });

    test('watchedShows ignores unwatched shows for genre and streak stats', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'watchedEpisodes': <String>[],
            'genres': [
              {'name': 'Horror'},
            ],
            'addedAt': '2026-08-28T02:00:00.000Z', // In night owl time range
          },
        ],
      );
      final nightOwl = results.firstWhere((a) => a.id == 'night_owl');
      expect(nightOwl.isUnlocked, false);

      final screamKing = results.firstWhere((a) => a.id == 'scream_king');
      expect(screamKing.currentValue, 0);
    });

    test('episode-level watch dates used for streak and marathon runner', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'id': 1,
            'watchedEpisodes': [
              'S01E01',
              'S01E02',
              'S01E03',
              'S01E04',
              'S01E05',
            ],
            'episodeWatchedDates': {
              'S01E01': '2026-08-20T10:00:00.000Z',
              'S01E02': '2026-08-20T11:00:00.000Z',
              'S01E03': '2026-08-20T12:00:00.000Z',
              'S01E04': '2026-08-20T13:00:00.000Z',
              'S01E05': '2026-08-20T14:00:00.000Z',
            },
          },
        ],
      );
      final marathon = results.firstWhere((a) => a.id == 'marathon_runner');
      expect(marathon.isUnlocked, true);
      expect(marathon.currentValue, 5);
    });

    test('getGenreDistribution returns empty list when no genres exist', () {
      final stats = AchievementsService.getGenreDistribution([], []);
      expect(stats, isEmpty);
    });

    test('getGenreDistribution groups into top 5 plus Other and calculates percentages', () {
      final movies = [
        {'genres': 'Action, Sci-Fi', 'isWatched': true},
        {'genres': 'Action, Drama', 'isWatched': true},
        {'genres': 'Comedy, Action', 'isWatched': true},
        {'genres': 'Horror', 'isWatched': true},
        {'genres': 'Animation', 'isWatched': true},
        {'genres': 'Thriller', 'isWatched': true},
        {'genres': 'Adventure', 'isWatched': true},
      ];

      final stats = AchievementsService.getGenreDistribution(movies, [], maxTopSlices: 5);

      // Total genre tags = 2 (Action, Sci-Fi) + 2 (Action, Drama) + 2 (Comedy, Action) + 1 (Horror) + 1 (Animation) + 1 (Thriller) + 1 (Adventure) = 10
      // Action: 3 (30%)
      // Sci-Fi, Drama, Comedy, Horror, Animation, Thriller, Adventure: 1 each
      // Top 5 + Other: exactly 6 slices
      expect(stats.length, 6);
      expect(stats[0].genre, 'Action');
      expect(stats[0].count, 3);
      expect(stats[0].percentage, 30.0);
      expect(stats.last.genre, 'Other');
      expect(stats.last.count, 3); // 8 unique genres - 5 top = 3 remaining = 3
      expect(stats.last.percentage, 30.0);

      final totalPercentage = stats.fold<double>(0, (sum, s) => sum + s.percentage);
      expect(totalPercentage, closeTo(100.0, 0.001));
    });
  });
}
