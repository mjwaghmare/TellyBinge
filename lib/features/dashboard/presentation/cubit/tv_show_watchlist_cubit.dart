import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';
import 'tv_show_watchlist_state.dart';
import '../../../../core/services/notification_service.dart';

class TvShowWatchlistCubit extends Cubit<TvShowWatchlistState> {
  final TvWatchlistRepository tvWatchlistRepository;
  StreamSubscription? _watchlistSubscription;
  final Map<int, _PendingShowStop> _pendingShowStops = {};

  final _failureController = StreamController<Failure>.broadcast();
  Stream<Failure> get failureStream => _failureController.stream;

  TvShowWatchlistCubit({required this.tvWatchlistRepository})
    : super(TvShowWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(TvShowWatchlistLoading());
    _watchlistSubscription?.cancel();

    _watchlistSubscription = tvWatchlistRepository
        .watchWatchlist(uid)
        .listen(
          (shows) {
            final mappedShows = _pendingShowStops.isEmpty
                ? shows
                : shows.map((s) {
                    final id = (s['id'] as num?)?.toInt();
                    if (id != null && _pendingShowStops.containsKey(id)) {
                      final copy = Map<String, dynamic>.from(s);
                      copy['status'] = 'STOPPED';
                      return copy;
                    }
                    return s;
                  }).toList();
            emit(TvShowWatchlistSuccess(mappedShows));
            // Widget sync is handled by the dashboard BlocConsumer listener
            // via WidgetService.syncWatchlistDataToWidget — do NOT duplicate here.

            // Hand the whole watchlist over; the service reconciles it against
            // what's actually scheduled. Shows that stopped airing or lost their
            // upcoming episode are simply absent here and get cancelled as a result.
            NotificationService().submitTitles(NotificationMedia.tv, [
              for (final show in mappedShows)
                if (show['status'] != 'STOPPED' &&
                    show['upcomingAirDate'] != null)
                  () {
                    final (
                      title,
                      body,
                    ) = NotificationService.generateTvNotificationContent(
                      showId: show['id'] as int,
                      showName: show['name'] as String? ?? 'Show',
                      episodeCode: show['upcomingEpisodeCode'] as String? ?? '',
                    );
                    return PendingNotification(
                      media: NotificationMedia.tv,
                      mediaId: show['id'] as int,
                      title: title,
                      body: body,
                      releaseDateStr: show['upcomingAirDate'] as String,
                    );
                  }(),
            ]);
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
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> stopWatchingShow({
    required String uid,
    required int showId,
  }) async {
    _pendingShowStops[showId]?.timer.cancel();
    _pendingShowStops.remove(showId);

    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          copy['status'] = 'STOPPED';
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.stopWatchingShow(uid: uid, showId: showId);
      await NotificationService()
          .cancelNotification(
            NotificationMedia.tv,
            showId,
          )
          .catchError((_) {});
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.stopWatchingShow: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  bool stageStopWatchingShow({
    required String uid,
    required int showId,
    Duration delay = const Duration(seconds: 4),
    VoidCallback? onCommitted,
  }) {
    if (state is! TvShowWatchlistSuccess) return false;

    final currentShows = (state as TvShowWatchlistSuccess).shows;
    final index = currentShows.indexWhere(
      (s) => (s['id'] as num?)?.toInt() == showId,
    );
    if (index == -1) return false;

    final showData = currentShows[index];
    final previousStatus = showData['status'] as String?;

    // Cancel existing pending stop timer for this show if any
    _pendingShowStops[showId]?.timer.cancel();

    // Optimistically mark as STOPPED
    final updatedShows = currentShows.map((s) {
      if ((s['id'] as num?)?.toInt() == showId) {
        final copy = Map<String, dynamic>.from(s);
        copy['status'] = 'STOPPED';
        return copy;
      }
      return s;
    }).toList();
    emit(TvShowWatchlistSuccess(updatedShows));

    late final _PendingShowStop pendingRecord;
    final timer = Timer(delay, () {
      pendingRecord.commitFuture = _commitStopWatchingShow(
        pendingRecord,
        onCommitted: onCommitted,
      );
    });

    pendingRecord = _PendingShowStop(
      uid: uid,
      showId: showId,
      previousStatus: previousStatus,
      timer: timer,
    );
    _pendingShowStops[showId] = pendingRecord;
    return true;
  }

  Future<void> _commitStopWatchingShow(
    _PendingShowStop pendingRecord, {
    VoidCallback? onCommitted,
  }) async {
    pendingRecord.isCommitting = true;
    try {
      await tvWatchlistRepository.stopWatchingShow(
        uid: pendingRecord.uid,
        showId: pendingRecord.showId,
      );
      if (_pendingShowStops[pendingRecord.showId] == pendingRecord) {
        _pendingShowStops.remove(pendingRecord.showId);
      }
      await NotificationService()
          .cancelNotification(NotificationMedia.tv, pendingRecord.showId)
          .catchError((_) {});
      onCommitted?.call();
    } catch (e) {
      if (_pendingShowStops[pendingRecord.showId] == pendingRecord) {
        _pendingShowStops.remove(pendingRecord.showId);
      }
      debugPrint('Error committing delayed stop watching: $e');
      if (!isClosed && state is TvShowWatchlistSuccess) {
        final restoredShows = (state as TvShowWatchlistSuccess).shows.map((s) {
          if ((s['id'] as num?)?.toInt() == pendingRecord.showId &&
              s['status'] == 'STOPPED') {
            final copy = Map<String, dynamic>.from(s);
            if (pendingRecord.previousStatus != null) {
              copy['status'] = pendingRecord.previousStatus;
            } else {
              copy.remove('status');
            }
            return copy;
          }
          return s;
        }).toList();
        emit(TvShowWatchlistSuccess(restoredShows));
      }
      final failure = Failure.fromException(e);
      if (!_failureController.isClosed) {
        _failureController.add(failure);
      }
    }
  }

  bool cancelPendingStopWatching(int showId) {
    final pending = _pendingShowStops[showId];
    if (pending == null || pending.isCommitting) return false;

    _pendingShowStops.remove(showId);
    pending.timer.cancel();

    if (!isClosed && state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          if (pending.previousStatus != null) {
            copy['status'] = pending.previousStatus;
          } else {
            copy.remove('status');
          }
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }
    return true;
  }

  Future<void> flushPendingStopWatching() async {
    if (_pendingShowStops.isEmpty) return;

    final pendingList = _pendingShowStops.values.toList();
    for (final pending in pendingList) {
      if (!pending.isCommitting) {
        pending.timer.cancel();
        pending.commitFuture = _commitStopWatchingShow(pending);
      }
    }

    await Future.wait(
      pendingList
          .map((p) => p.commitFuture)
          .whereType<Future<void>>(),
    );
  }

  Future<void> continueWatchingShow({
    required String uid,
    required int showId,
  }) async {
    _pendingShowStops[showId]?.timer.cancel();
    _pendingShowStops.remove(showId);

    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          copy.remove('status');
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.continueWatchingShow(
        uid: uid,
        showId: showId,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.continueWatchingShow: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> removeShow({required String uid, required int showId}) async {
    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows
          .where((s) => (s['id'] as num?)?.toInt() != showId)
          .toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.removeShow(uid: uid, showId: showId);
      await NotificationService().cancelNotification(
        NotificationMedia.tv,
        showId,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.removeShow: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
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
    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          final watched = List<dynamic>.from(
            copy['watchedEpisodes'] as List? ?? [],
          );
          final dates = Map<String, dynamic>.from(
            copy['episodeWatchedDates'] as Map? ?? {},
          );
          if (isWatched) {
            if (!watched.contains(episodeKey)) watched.add(episodeKey);
            dates[episodeKey] = DateTime.now().toIso8601String();
          } else {
            watched.remove(episodeKey);
            dates.remove(episodeKey);
          }
          copy['watchedEpisodes'] = watched;
          copy['episodeWatchedDates'] = dates;
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

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
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> markMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          final watched = List<dynamic>.from(
            copy['watchedEpisodes'] as List? ?? [],
          );
          final dates = Map<String, dynamic>.from(
            copy['episodeWatchedDates'] as Map? ?? {},
          );
          final now = DateTime.now().toIso8601String();
          for (final key in episodeKeys) {
            if (!watched.contains(key)) watched.add(key);
            dates[key] = now;
          }
          copy['watchedEpisodes'] = watched;
          copy['episodeWatchedDates'] = dates;
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.markMultipleEpisodesWatched(
        uid: uid,
        showId: showId,
        episodeKeys: episodeKeys,
      );
    } catch (e) {
      debugPrint(
        'Error in TvShowWatchlistCubit.markMultipleEpisodesWatched: $e',
      );
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          final watched = List<dynamic>.from(
            copy['watchedEpisodes'] as List? ?? [],
          );
          final dates = Map<String, dynamic>.from(
            copy['episodeWatchedDates'] as Map? ?? {},
          );
          for (final key in episodeKeys) {
            watched.remove(key);
            dates.remove(key);
          }
          copy['watchedEpisodes'] = watched;
          copy['episodeWatchedDates'] = dates;
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.unmarkMultipleEpisodesWatched(
        uid: uid,
        showId: showId,
        episodeKeys: episodeKeys,
      );
    } catch (e) {
      debugPrint(
        'Error in TvShowWatchlistCubit.unmarkMultipleEpisodesWatched: $e',
      );
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> toggleFavorite({
    required String uid,
    required int showId,
    required bool isFavorite,
  }) async {
    final previousState = state;
    if (state is TvShowWatchlistSuccess) {
      final currentShows = (state as TvShowWatchlistSuccess).shows;
      final updatedShows = currentShows.map((s) {
        if ((s['id'] as num?)?.toInt() == showId) {
          final copy = Map<String, dynamic>.from(s);
          copy['isFavorite'] = isFavorite;
          return copy;
        }
        return s;
      }).toList();
      emit(TvShowWatchlistSuccess(updatedShows));
    }

    try {
      await tvWatchlistRepository.toggleFavorite(
        uid: uid,
        showId: showId,
        isFavorite: isFavorite,
      );
    } catch (e) {
      debugPrint('Error in TvShowWatchlistCubit.toggleFavorite: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  void clearWatchlist() {
    unawaited(flushPendingStopWatching());
    _watchlistSubscription?.cancel();
    _watchlistSubscription = null;
    emit(TvShowWatchlistInitial());
  }

  @override
  Future<void> close() async {
    await flushPendingStopWatching();
    await _watchlistSubscription?.cancel();
    await _failureController.close();
    return super.close();
  }
}

class _PendingShowStop {
  final String uid;
  final int showId;
  final String? previousStatus;
  final Timer timer;
  bool isCommitting = false;
  Future<void>? commitFuture;

  _PendingShowStop({
    required this.uid,
    required this.showId,
    required this.previousStatus,
    required this.timer,
  });
}
