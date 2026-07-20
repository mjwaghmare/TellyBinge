import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';
import 'tv_show_watchlist_state.dart';
import '../../../../core/services/widget_service.dart';
import '../../../../core/services/notification_service.dart';
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
        _updateWidgetWithNextShow(shows);
        
        // Schedule notifications for upcoming episodes
        for (var show in shows) {
          if (show['status'] != 'STOPPED' && show['upcomingAirDate'] != null) {
            final showId = show['id'] as int;
            final showName = show['name'] as String;
            final epCode = show['upcomingEpisodeCode'] as String? ?? '';
            NotificationService().scheduleBasedOnSettings(
              id: showId,
              title: 'New Episode: $showName',
              body: 'Episode $epCode is airing soon!',
              releaseDateStr: show['upcomingAirDate'] as String,
            );
          }
        }
      },
      onError: (error) {
        emit(TvShowWatchlistError(error.toString()));
      },
    );
  }

  void _updateWidgetWithNextShow(List<Map<String, dynamic>> shows) {
    // Priority 1: Watch Next
    final watchNext = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        show['category'] != 'UP_TO_DATE' &&
        show['category'] != 'HAVENT_STARTED' &&
        show['nextEpisodeCode'] != null &&
        show['nextEpisodeCode'].toString().isNotEmpty &&
        !show['nextEpisodeCode'].toString().startsWith('Up to date')
    ).toList();

    // Priority 2: Haven't Started
    final haventStarted = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        show['category'] == 'HAVENT_STARTED'
    ).toList();

    // Priority 3: Upcoming
    final upcoming = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        (show['category'] == 'UP_TO_DATE' || show['hasUpcoming'] == true) &&
        show['upcomingEpisodeCode'] != null &&
        show['upcomingEpisodeCode'] != 'TBA'
    ).toList();

    final List<Map<String, dynamic>> widgetItems = [];

    // Fill from Watch Next first
    for (var show in watchNext) {
      if (widgetItems.length >= 3) break;
      final int targetSeason = (show['targetSeason'] as num?)?.toInt() ?? 0;
      final int targetEpisode = (show['targetEpisode'] as num?)?.toInt() ?? 0;
      final String firestoreKey = '$targetSeason-$targetEpisode';
      widgetItems.add({
        'showId': show['id'] as int,
        'showName': show['name'] as String,
        'header': show['isPremiere'] == true ? 'PREMIERE' : (show['isNewEpisode'] == true ? 'NEW EPISODE' : 'UP NEXT'),
        'episodeTitle': show['nextEpisodeCode'] as String,
        'episodeDetails': show['nextEpisodeTitle'] as String,
        'posterPath': show['posterPath'] as String?,
        'episodeKey': firestoreKey,
      });
    }

    // Backfill remaining slots from Haven't Started
    for (var show in haventStarted) {
      if (widgetItems.length >= 3) break;
      final episodeTitle = (show['nextEpisodeCode'] != null && show['nextEpisodeCode'].toString().isNotEmpty)
          ? show['nextEpisodeCode'] as String
          : 'S01 | E01';
      final episodeDetails = (show['nextEpisodeTitle'] != null && show['nextEpisodeTitle'].toString().isNotEmpty)
          ? show['nextEpisodeTitle'] as String
          : 'Pilot';
      widgetItems.add({
        'showId': show['id'] as int,
        'showName': show['name'] as String,
        'header': 'START WATCHING',
        'episodeTitle': episodeTitle,
        'episodeDetails': episodeDetails,
        'posterPath': show['posterPath'] as String?,
        'episodeKey': '1-1',
      });
    }

    // If both Watch Next and Haven't Started are empty, fall back to Upcoming
    if (widgetItems.isEmpty) {
      for (var show in upcoming) {
        if (widgetItems.length >= 3) break;

        String upcomingDetail = show['upcomingEpisodeTitle'] ?? '';
        if (show['upcomingAirDate'] != null) {
            final airDate = DateTime.tryParse(show['upcomingAirDate']);
            if (airDate != null) {
                final days = airDate.difference(DateTime.now()).inDays;
                if (days > 0) {
                    upcomingDetail = 'In $days days • $upcomingDetail';
                } else if (days == 0) {
                    upcomingDetail = 'Today • $upcomingDetail';
                }
            }
        }

        widgetItems.add({
          'showId': show['id'] as int,
          'showName': show['name'] as String,
          'header': show['upcomingIsPremiere'] == true ? 'NEXT SEASON' : 'UPCOMING',
          'episodeTitle': show['upcomingEpisodeCode'] as String,
          'episodeDetails': upcomingDetail,
          'posterPath': show['posterPath'] as String?,
          'episodeKey': '',
        });
      }
    }

    WidgetService.updateUpNextWidget(widgetItems);
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
      await NotificationService().cancelNotification(showId);
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
      await NotificationService().cancelNotification(showId);
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
