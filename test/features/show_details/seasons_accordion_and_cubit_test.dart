import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/show_details/presentation/cubit/show_details_cubit.dart';
import 'package:popverse/features/show_details/presentation/pages/show_details_page.dart';

void main() {
  group('ShowDetailsCubit.computeLatestSeasonNum', () {
    test('uses greatest season_number among validSeasons rather than list order', () {
      final seasonsList = [
        {'season_number': 3, 'episode_count': 10},
        {'season_number': 1, 'episode_count': 8},
        {'season_number': 2, 'episode_count': 6},
      ];

      final latestSeason = ShowDetailsCubit.computeLatestSeasonNum(
        seasonsList: seasonsList,
        firstSeasonNum: 1,
        numberOfSeasons: 3,
      );

      expect(latestSeason, 3);
    });

    test('ignores announced seasons with 0 episodes', () {
      final seasonsList = [
        {'season_number': 1, 'episode_count': 10},
        {'season_number': 2, 'episode_count': 8},
        {'season_number': 3, 'episode_count': 0}, // Announced / empty placeholder
      ];

      final latestSeason = ShowDetailsCubit.computeLatestSeasonNum(
        seasonsList: seasonsList,
        firstSeasonNum: 1,
        numberOfSeasons: 3,
      );

      // Must be Season 2, not announced Season 3
      expect(latestSeason, 2);
    });

    test('retains fallback behavior when no valid seasons have episodes', () {
      final seasonsList = [
        {'season_number': 1, 'episode_count': 0},
      ];

      final fallbackWithNumSeasons = ShowDetailsCubit.computeLatestSeasonNum(
        seasonsList: seasonsList,
        firstSeasonNum: 1,
        numberOfSeasons: 2,
      );
      expect(fallbackWithNumSeasons, 2);

      final fallbackToFirst = ShowDetailsCubit.computeLatestSeasonNum(
        seasonsList: seasonsList,
        firstSeasonNum: 1,
        numberOfSeasons: null,
      );
      expect(fallbackToFirst, 1);
    });
  });

  group('ShowDetailsPage.computeLatestSeasonNumber', () {
    test('excludes announced seasons with zero episodes matching visible accordion seasons', () {
      final seasons = [
        {'season_number': 0, 'episode_count': 5}, // Specials skipped
        {'season_number': 1, 'episode_count': 10},
        {'season_number': 2, 'episode_count': 8},
        {'season_number': 3, 'episode_count': 0}, // Announced with 0 episodes
      ];
      final seasonsData = <int, List<dynamic>>{
        1: [{'episode_number': 1}],
        2: [{'episode_number': 1}],
      };

      final latest = ShowDetailsPage.computeLatestSeasonNumber(seasons, seasonsData);
      // Season 2 is the latest visible season, preventing Season 2 future episodes from being treated as released
      expect(latest, 2);
    });

    test('includes season with zero epCount if episodes have loaded into seasonsData', () {
      final seasons = [
        {'season_number': 1, 'episode_count': 10},
        {'season_number': 2, 'episode_count': 0}, // epCount was 0 in show summary
      ];
      final seasonsData = <int, List<dynamic>>{
        2: [{'episode_number': 1, 'air_date': '2026-01-01'}], // loaded into seasonsData
      };

      final latest = ShowDetailsPage.computeLatestSeasonNumber(seasons, seasonsData);
      expect(latest, 2);
    });

    test('returns 0 when no seasons have episodes or loaded data', () {
      final seasons = [
        {'season_number': 0, 'episode_count': 0},
        {'season_number': 1, 'episode_count': 0},
      ];
      final seasonsData = <int, List<dynamic>>{};

      final latest = ShowDetailsPage.computeLatestSeasonNumber(seasons, seasonsData);
      expect(latest, 0);
    });
  });
}
