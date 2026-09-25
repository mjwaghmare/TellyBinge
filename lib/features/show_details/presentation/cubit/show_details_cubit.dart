import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/tmdb_client.dart';
import 'show_details_state.dart';

class ShowDetailsCubit extends Cubit<ShowDetailsState> {
  final TmdbClient tmdbClient;
  int _loadGeneration = 0;

  ShowDetailsCubit({required this.tmdbClient}) : super(ShowDetailsInitial());

  Future<void> loadDetails(int id, String mediaType) async {
    final capturedGeneration = ++_loadGeneration;
    emit(ShowDetailsLoading());
    try {
      if (mediaType == 'movie') {
        final details = await tmdbClient.getMovieDetails(id);
        if (_loadGeneration != capturedGeneration) return;
        emit(
          ShowDetailsSuccess(
            details: details,
            mediaType: mediaType,
            seasonsData: const {},
          ),
        );
      } else {
        final details = await tmdbClient.getTvShowDetails(id);
        if (_loadGeneration != capturedGeneration) return;
        final Map<int, List<dynamic>> initialSeasons = {};

        // Emit initial details success with secondary loading states
        emit(
          ShowDetailsSuccess(
            details: details,
            mediaType: mediaType,
            seasonsData: initialSeasons,
            isCastLoading: true,
            isSimilarLoading: true,
          ),
        );

        // Helper to get current success state
        ShowDetailsSuccess? getSuccessState() {
          if (isClosed ||
              state is! ShowDetailsSuccess ||
              _loadGeneration != capturedGeneration) {
            return null;
          }
          return state as ShowDetailsSuccess;
        }

        // 1. Fetch Cast independently
        unawaited(
          tmdbClient
              .getTvCredits(id)
              .then((credits) {
                final s = getSuccessState();
                if (s != null) {
                  final updatedDetails = Map<String, dynamic>.from(s.details);
                  updatedDetails['credits'] = credits;
                  emit(s.copyWith(details: updatedDetails, isCastLoading: false));
                }
              })
              .catchError((_) {
                final s = getSuccessState();
                if (s != null) {
                  emit(s.copyWith(isCastLoading: false));
                }
              }),
        );

        // 2. Fetch Similar independently
        unawaited(
          tmdbClient
              .getSimilarTvShows(id)
              .then((similarShows) {
                final s = getSuccessState();
                if (s != null) {
                  final updatedDetails = Map<String, dynamic>.from(s.details);
                  updatedDetails['similar'] = {'results': similarShows};
                  emit(
                    s.copyWith(details: updatedDetails, isSimilarLoading: false),
                  );
                }
              })
              .catchError((_) {
                final s = getSuccessState();
                if (s != null) {
                  emit(s.copyWith(isSimilarLoading: false));
                }
              }),
        );

        // Prefetch Season 1 episodes for immediate display (non-blocking for main UI)
        final seasonsList = details['seasons'] as List<dynamic>? ?? [];
        if (seasonsList.isNotEmpty) {
          // Find the first actual season (season_number > 0), skip specials
          final firstActualSeason = seasonsList.firstWhere(
            (s) => ((s['season_number'] as num?)?.toInt() ?? 0) > 0,
            orElse: () => seasonsList[0],
          );
          final firstSeasonNum =
              (firstActualSeason['season_number'] as num?)?.toInt() ?? 1;
          final totalSeasons =
              (details['number_of_seasons'] as num?)?.toInt() ?? 0;

          final futures = <Future>[loadSeasonEpisodes(id, firstSeasonNum)];
          if (totalSeasons > firstSeasonNum) {
            futures.add(loadSeasonEpisodes(id, totalSeasons));
          }
          try {
            await Future.wait(futures);
          } catch (_) {
            // Non-critical: let user expand season to retry if prefetch fails on slow connection
          }
        }
      }
    } catch (e) {
      if (_loadGeneration == capturedGeneration) {
        emit(ShowDetailsError(Failure.fromException(e)));
      }
    }
  }

  Future<void> loadSeasonEpisodes(int tvId, int seasonNumber) async {
    final capturedGeneration = _loadGeneration;
    final currentState = state;
    if (currentState is! ShowDetailsSuccess) return;

    // If season is already loaded, skip fetching
    if (currentState.seasonsData.containsKey(seasonNumber)) return;

    try {
      final seasonDetails = await tmdbClient.getTvSeasonDetails(
        tvId,
        seasonNumber,
      );
      final episodes = seasonDetails['episodes'] as List<dynamic>? ?? [];

      final latestState = state;
      if (latestState is! ShowDetailsSuccess ||
          _loadGeneration != capturedGeneration) {
        return;
      }

      final updatedSeasonsData = Map<int, List<dynamic>>.from(
        latestState.seasonsData,
      );
      updatedSeasonsData[seasonNumber] = episodes;

      emit(latestState.copyWith(seasonsData: updatedSeasonsData));
    } catch (e) {
      final latestState = state;
      if (latestState is! ShowDetailsSuccess ||
          _loadGeneration != capturedGeneration) {
        return;
      }

      // Set to empty list on error so the loader stops spinning endlessly
      final updatedSeasonsData = Map<int, List<dynamic>>.from(
        latestState.seasonsData,
      );
      updatedSeasonsData[seasonNumber] = [];
      emit(latestState.copyWith(seasonsData: updatedSeasonsData));
    }
  }
}
