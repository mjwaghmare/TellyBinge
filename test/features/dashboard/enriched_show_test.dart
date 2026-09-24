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
  });
}
