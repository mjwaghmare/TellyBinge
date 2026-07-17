import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';
import 'tv_show_watchlist_state.dart';

class TvShowWatchlistCubit extends Cubit<TvShowWatchlistState> {
  final TvWatchlistRepository tvWatchlistRepository;
  StreamSubscription? _watchlistSubscription;

  TvShowWatchlistCubit({required this.tvWatchlistRepository})
      : super(TvShowWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(TvShowWatchlistLoading());
    _watchlistSubscription?.cancel();
    
    _watchlistSubscription = tvWatchlistRepository.watchWatchlist(uid).listen(
      (shows) {
        emit(TvShowWatchlistSuccess(shows));
      },
      onError: (error) {
        emit(TvShowWatchlistError(error.toString()));
      },
    );
  }

  Future<void> addShow({
    required String uid,
    required int showId,
    required String name,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double voteAverage,
  }) async {
    try {
      await tvWatchlistRepository.addShow(
        uid: uid,
        showId: showId,
        name: name,
        posterPath: posterPath,
        backdropPath: backdropPath,
        firstAirDate: firstAirDate,
        voteAverage: voteAverage,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.addShow: $e');
    }
  }

  Future<void> stopWatchingShow({
    required String uid,
    required int showId,
  }) async {
    try {
      await tvWatchlistRepository.stopWatchingShow(uid: uid, showId: showId);
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.stopWatchingShow: $e');
    }
  }

  Future<void> continueWatchingShow({
    required String uid,
    required int showId,
  }) async {
    try {
      await tvWatchlistRepository.continueWatchingShow(uid: uid, showId: showId);
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.continueWatchingShow: $e');
    }
  }

  Future<void> removeShow({
    required String uid,
    required int showId,
  }) async {
    try {
      await tvWatchlistRepository.removeShow(uid: uid, showId: showId);
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.removeShow: $e');
    }
  }

  Future<void> toggleEpisodeWatched({
    required String uid,
    required int showId,
    required String episodeKey,
    required bool isWatched,
    String? showName,
    String? showPoster,
    String? episodeTitle,
  }) async {
    try {
      await tvWatchlistRepository.toggleEpisodeWatched(
        uid: uid,
        showId: showId,
        episodeKey: episodeKey,
        isWatched: isWatched,
        showName: showName,
        showPoster: showPoster,
        episodeTitle: episodeTitle,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.toggleEpisodeWatched: $e');
    }
  }

  Future<void> markMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    try {
      await tvWatchlistRepository.markMultipleEpisodesWatched(
        uid: uid,
        showId: showId,
        episodeKeys: episodeKeys,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.markMultipleEpisodesWatched: $e');
    }
  }

  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    try {
      await tvWatchlistRepository.unmarkMultipleEpisodesWatched(
        uid: uid,
        showId: showId,
        episodeKeys: episodeKeys,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.unmarkMultipleEpisodesWatched: $e');
    }
  }

  @override
  Future<void> close() {
    _watchlistSubscription?.cancel();
    return super.close();
  }
}
