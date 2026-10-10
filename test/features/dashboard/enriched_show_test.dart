import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/dashboard/presentation/models/enriched_show.dart';

void main() {
  EnrichedShow makeShow({
    required int targetSeason,
    required int targetEpisode,
    int totalEpisodes = 10,
    required Map<String, dynamic> rawShowData,
  }) {
    return EnrichedShow(
      rawShowData: rawShowData,
      episodeCode: 'S${targetSeason}E$targetEpisode',
      episodeTitle: 'Test Episode',
      isPremiere: false,
      isNew: false,
      isUpToDate: false,
      targetSeason: targetSeason,
      targetEpisode: targetEpisode,
      totalEpisodes: totalEpisodes,
      watchlistStatus: 'WATCH_NEXT',
      upcomingEpisodeCode: '',
      upcomingEpisodeTitle: '',
      upcomingIsPremiere: false,
      upcomingIsNew: false,
      hasUpcoming: false,
    );
  }

  group('EnrichedShow finale detection', () {
    test('isSeasonFinale is true when targetEpisode equals season episode_count', () {
      final show = makeShow(
        targetSeason: 1,
        targetEpisode: 10,
        rawShowData: {
          'seasons': [
            {'season_number': 0, 'episode_count': 3},
            {'season_number': 1, 'episode_count': 10},
          ],
        },
      );
      expect(show.isSeasonFinale, isTrue);
    });

    test('isSeasonFinale is false for mid-season episodes or specials', () {
      final midSeason = makeShow(
        targetSeason: 1,
        targetEpisode: 5,
        rawShowData: {
          'seasons': [
            {'season_number': 1, 'episode_count': 10},
          ],
        },
      );
      expect(midSeason.isSeasonFinale, isFalse);

      final special = makeShow(
        targetSeason: 0,
        targetEpisode: 3,
        rawShowData: {
          'seasons': [
            {'season_number': 0, 'episode_count': 3},
          ],
        },
      );
      expect(special.isSeasonFinale, isFalse);
    });

    test('isSeriesFinale is false for ongoing / returning series even on last season finale', () {
      final returningShow = makeShow(
        targetSeason: 2,
        targetEpisode: 8,
        totalEpisodes: 18,
        rawShowData: {
          'status': 'Returning Series',
          'number_of_seasons': 2,
          'seasons': [
            {'season_number': 1, 'episode_count': 10},
            {'season_number': 2, 'episode_count': 8},
          ],
          'watchedEpisodes': ['1-1', '1-2'],
        },
      );
      expect(returningShow.isSeasonFinale, isTrue);
      // Must NOT claim series complete for returning series!
      expect(returningShow.isSeriesFinale, isFalse);
    });

    test('isSeriesFinale is true for ended series when all episodes watched', () {
      final endedShow = makeShow(
        targetSeason: 2,
        targetEpisode: 4,
        totalEpisodes: 8,
        rawShowData: {
          'status': 'Ended',
          'number_of_seasons': 2,
          'seasons': [
            {'season_number': 1, 'episode_count': 4},
            {'season_number': 2, 'episode_count': 4},
          ],
          'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '2-1', '2-2', '2-3'],
        },
      );
      expect(endedShow.isSeasonFinale, isTrue);
      expect(endedShow.isSeriesFinale, isTrue);
    });

    test('isSeriesFinale is true for ended series even with trailing empty placeholder seasons', () {
      final endedShowWithPlaceholders = makeShow(
        targetSeason: 3,
        targetEpisode: 6,
        totalEpisodes: 18,
        rawShowData: {
          'status': 'Ended',
          'number_of_seasons': 5,
          'seasons': [
            {'season_number': 1, 'episode_count': 6},
            {'season_number': 2, 'episode_count': 6},
            {'season_number': 3, 'episode_count': 6},
            {'season_number': 4, 'episode_count': 0},
            {'season_number': 5, 'episode_count': 0},
          ],
          'watchedEpisodes': [
            for (int e = 1; e <= 6; e++) '1-$e',
            for (int e = 1; e <= 6; e++) '2-$e',
            for (int e = 1; e <= 5; e++) '3-$e',
          ],
        },
      );
      expect(endedShowWithPlaceholders.isSeasonFinale, isTrue);
      expect(endedShowWithPlaceholders.isSeriesFinale, isTrue);
    });
  });

  group('EnrichedShow category derivation', () {
    test('never marks show as FINISHED when watchedEpisodes is empty', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Cupertino',
        'category': 'FINISHED',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 3,
      });
      expect(show.watchlistStatus, 'HAVENT_STARTED');
    });

    test('preserves UPCOMING_ONLY when watchedEpisodes is empty', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Future Show',
        'category': 'UPCOMING_ONLY',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 10,
      });
      expect(show.watchlistStatus, 'UPCOMING_ONLY');
    });

    test('marks as WATCH_NEXT when aired unwatched episode is established', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Ongoing Show',
        'category': 'FINISHED',
        'nextEpisodeCode': 'S01 | E02',
        'watchedEpisodes': ['1-1'],
        'totalEpisodes': 10,
      });
      expect(show.watchlistStatus, 'WATCH_NEXT');
    });

    test('preserves UP_TO_DATE even when watchedCount < totalEpisodes without aired unwatched', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Waiting For Season 2',
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': 'Up to date',
        'watchedEpisodes': ['1-1', '1-2'],
        'totalEpisodes': 10,
      });
      expect(show.watchlistStatus, 'UP_TO_DATE');
    });

    test('differently padded codes for upcoming episode match and do not mark WATCH_NEXT before air date', () {
      final futureDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      final show = EnrichedShow.fromShowData({
        'name': 'Upcoming Episode Show',
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': 'S01 | E03',
        'upcomingEpisodeCode': 'S1 | E3',
        'hasUpcoming': true,
        'upcomingAirDate': futureDate,
        'watchedEpisodes': ['1-1', '1-2'],
        'targetSeason': 1,
        'targetEpisode': 3,
        'totalEpisodes': 10,
      });
      expect(show.watchlistStatus, 'UP_TO_DATE');
    });

    test('stale nextEpisodeCode for already watched episode does not mark FINISHED show as WATCH_NEXT', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Completed Series With Stale Code',
        'category': 'FINISHED',
        'nextEpisodeCode': 'S01 | E03',
        'watchedEpisodes': ['1-1', '1-2', '1-3'],
        'targetSeason': 1,
        'targetEpisode': 3,
        'totalEpisodes': 3,
      });
      expect(show.watchlistStatus, 'FINISHED');
      expect(show.episodeCode, 'Up to date');
    });

    test('stale nextEpisodeCode does not override completion when watchedCount matches totalEpisodes', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Completed Show Count Match',
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': 'S01 | E05',
        'watchedEpisodes': ['1-1', '1-2', '1-3', '1-4', '1-5'],
        'totalEpisodes': 5,
      });
      expect(show.watchlistStatus, 'UP_TO_DATE');
      expect(show.episodeCode, 'Up to date');
    });

    test('codesMatch compares upcoming episode with targetSeason and targetEpisode rather than stale storedNextCode', () {
      final futureDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      final show = EnrichedShow.fromShowData({
        'name': 'Target Match Show',
        'category': 'UP_TO_DATE',
        'nextEpisodeCode': 'S01 | E01', // stale: episode 1 already watched
        'upcomingEpisodeCode': 'S1 | E2', // upcoming is episode 2, which matches target
        'hasUpcoming': true,
        'upcomingAirDate': futureDate,
        'watchedEpisodes': ['1-1'],
        'targetSeason': 1,
        'targetEpisode': 2,
        'totalEpisodes': 10,
      });
      // Should match upcoming episode 2 with targetEpisode 2, so show is UP_TO_DATE
      expect(show.watchlistStatus, 'UP_TO_DATE');
    });

    test('exact-code fallback cannot match stored code for a different target episode', () {
      final futureDate = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      final show = EnrichedShow.fromShowData({
        'name': 'Fallback Constraint Show',
        'category': 'WATCH_NEXT',
        'nextEpisodeCode': 'S01 | E01', // stale code for episode 1
        'upcomingEpisodeCode': 'S01 | E01', // upcoming code says episode 1
        'hasUpcoming': true,
        'upcomingAirDate': futureDate,
        'watchedEpisodes': ['1-1'], // episode 1 already watched, target is 1-2
        'targetSeason': 1,
        'targetEpisode': 2,
        'totalEpisodes': 10,
      });
      // Since target is episode 2, upcoming episode 1 must NOT match target,
      // so isNextUpcoming is false and category stays WATCH_NEXT instead of flipping to UP_TO_DATE
      expect(show.watchlistStatus, 'WATCH_NEXT');
    });

    test('preserves stored TBA episodeCode and fallback title instead of deriving S01 | E01 or clearing title', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Unreleased Show',
        'category': 'UPCOMING_ONLY',
        'nextEpisodeCode': 'TBA',
        'nextEpisodeTitle': 'Waiting for premiere',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 0,
      });
      expect(show.episodeCode, 'TBA');
      expect(show.episodeTitle, 'Waiting for premiere');
      expect(show.watchlistStatus, 'UPCOMING_ONLY');

      final endedShow = EnrichedShow.fromShowData({
        'name': 'Ended Unstarted Show',
        'category': 'HAVENT_STARTED',
        'nextEpisodeCode': 'TBA',
        'nextEpisodeTitle': "Haven't started",
        'status': 'Ended',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 0,
      });
      expect(endedShow.episodeCode, 'TBA');
      expect(endedShow.episodeTitle, "Haven't started");
      expect(endedShow.watchlistStatus, 'HAVENT_STARTED');
    });

    test('lowercase and padded TBA values use the fallback title', () {
      final show = EnrichedShow.fromShowData({
        'name': 'Padded TBA Show',
        'category': 'UPCOMING_ONLY',
        'nextEpisodeCode': '  tba  ',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 0,
      });
      expect(show.episodeCode.trim().toUpperCase(), 'TBA');
      expect(show.episodeTitle, 'Waiting for premiere');

      final endedShow = EnrichedShow.fromShowData({
        'name': 'Ended Lowercase TBA Show',
        'category': 'HAVENT_STARTED',
        'nextEpisodeCode': 'tba',
        'status': 'Ended',
        'watchedEpisodes': <String>[],
        'totalEpisodes': 0,
      });
      expect(endedShow.episodeCode.trim().toUpperCase(), 'TBA');
      expect(endedShow.episodeTitle, "Haven't started");
    });
  });
}
