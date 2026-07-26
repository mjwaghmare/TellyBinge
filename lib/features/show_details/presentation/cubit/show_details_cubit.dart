import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'show_details_state.dart';

class ShowDetailsCubit extends Cubit<ShowDetailsState> {
  final TmdbClient tmdbClient;

  ShowDetailsCubit({required this.tmdbClient})
      : super(ShowDetailsInitial());

  Future<void> loadDetails(int id, String mediaType) async {
    emit(ShowDetailsLoading());
    try {
      if (mediaType == 'movie') {
        final details = await tmdbClient.getMovieDetails(id);
        emit(ShowDetailsSuccess(
          details: details,
          mediaType: mediaType,
          seasonsData: const {},
        ));
      } else {
        final details = await tmdbClient.getTvShowDetails(id);
        final Map<int, List<dynamic>> initialSeasons = {};
        
        // Emit initial details success
        emit(ShowDetailsSuccess(
          details: details,
          mediaType: mediaType,
          seasonsData: initialSeasons,
        ));

        // Prefetch Season 1 episodes for immediate display
        final seasonsList = details['seasons'] as List<dynamic>? ?? [];
        if (seasonsList.isNotEmpty) {
          // Find the first actual season (season_number > 0), skip specials
          final firstActualSeason = seasonsList.firstWhere(
            (s) => ((s['season_number'] as num?)?.toInt() ?? 0) > 0,
            orElse: () => seasonsList[0],
          );
          final firstSeasonNum = (firstActualSeason['season_number'] as num?)?.toInt() ?? 1;
          final totalSeasons = (details['number_of_seasons'] as num?)?.toInt() ?? 0;

          final futures = <Future>[loadSeasonEpisodes(id, firstSeasonNum)];
          if (totalSeasons > firstSeasonNum) {
            futures.add(loadSeasonEpisodes(id, totalSeasons));
          }
          await Future.wait(futures);
        }
      }
    } catch (e) {
      emit(ShowDetailsError(e.toString()));
    }
  }

  Future<void> loadSeasonEpisodes(int tvId, int seasonNumber) async {
    final currentState = state;
    if (currentState is! ShowDetailsSuccess) return;

    // If season is already loaded, skip fetching
    if (currentState.seasonsData.containsKey(seasonNumber)) return;

    try {
      final seasonDetails = await tmdbClient.getTvSeasonDetails(tvId, seasonNumber);
      final episodes = seasonDetails['episodes'] as List<dynamic>? ?? [];

      final updatedSeasonsData = Map<int, List<dynamic>>.from(currentState.seasonsData);
      updatedSeasonsData[seasonNumber] = episodes;

      emit(currentState.copyWith(seasonsData: updatedSeasonsData));
    } catch (e) {
      // Set to empty list on error so the loader stops spinning endlessly
      final updatedSeasonsData = Map<int, List<dynamic>>.from(currentState.seasonsData);
      updatedSeasonsData[seasonNumber] = [];
      emit(currentState.copyWith(seasonsData: updatedSeasonsData));
    }
  }
}
