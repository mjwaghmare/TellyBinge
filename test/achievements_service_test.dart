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

    test('series_finisher does not count show as complete when category is WATCH_NEXT with aired next episode', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'category': 'WATCH_NEXT',
            'nextEpisodeCode': 'S02 | E01',
            'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '1-5'],
            'totalEpisodes': 5,
            'hasUpcoming': false,
          },
        ],
      );
      final finisher = results.firstWhere((a) => a.id == 'series_finisher');
      expect(finisher.currentValue, 0);
      expect(finisher.isUnlocked, false);
    });

    test('series_finisher counts show as complete when watchedCount matches and no aired next episode', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'category': 'UP_TO_DATE',
            'nextEpisodeCode': 'Up to date',
            'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '1-5'],
            'totalEpisodes': 5,
            'hasUpcoming': false,
          },
        ],
      );
      final finisher = results.firstWhere((a) => a.id == 'series_finisher');
      expect(finisher.currentValue, 1);
      expect(finisher.isUnlocked, true);
    });

    test('series_finisher determines unwatched next episode from watched keys even when category is not WATCH_NEXT', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'category': 'IN_PROGRESS', // Not WATCH_NEXT
            'nextEpisodeCode': 'S02 | E01',
            'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '1-5'],
            'totalEpisodes': 5,
            'hasUpcoming': false,
          },
        ],
      );
      final finisher = results.firstWhere((a) => a.id == 'series_finisher');
      // S02E01 has aired and is not in watchedEpisodes, so show cannot be counted complete
      expect(finisher.currentValue, 0);
      expect(finisher.isUnlocked, false);
    });

    test('series_finisher counts complete when nextEpisodeCode is already in watchedEpisodes even if non-empty', () {
      final results = AchievementsService.evaluate(
        movies: [],
        shows: [
          {
            'category': 'UP_TO_DATE',
            'nextEpisodeCode': 'S01 | E05', // Already in watchedEpisodes (stale)
            'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '1-5'],
            'totalEpisodes': 5,
            'hasUpcoming': false,
          },
        ],
      );
      final finisher = results.firstWhere((a) => a.id == 'series_finisher');
      // S01E05 is already watched, so no aired unwatched episode exists
      expect(finisher.currentValue, 1);
      expect(finisher.isUnlocked, true);
    });
  });
}
