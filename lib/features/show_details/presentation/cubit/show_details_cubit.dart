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
            (s) => (s['season_number'] as int? ?? 0) > 0,
            orElse: () => seasonsList[0],
          );
          final firstSeasonNum = firstActualSeason['season_number'] as int? ?? 1;
          await loadSeasonEpisodes(id, firstSeasonNum);
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
      // Log error but preserve state
      // We can also emit a transient error if needed, but keeping the current screen visible is safer
    }
  }
}
