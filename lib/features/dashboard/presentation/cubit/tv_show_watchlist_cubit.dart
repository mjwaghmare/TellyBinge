import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';
import 'tv_show_watchlist_state.dart';
import '../../../../core/services/notification_service.dart';

class TvShowWatchlistCubit extends Cubit<TvShowWatchlistState> {
  final TvWatchlistRepository tvWatchlistRepository;
  final TmdbClient? tmdbClient;
  StreamSubscription? _watchlistSubscription;
  final Map<int, _PendingShowStop> _pendingShowStops = {};
  final Set<int> _backfillingShowIds = {};

  /// Shows TMDB has no country or language for, for [_watchedUid]. Retrying
  /// them on every watchlist emission used to fetch and rewrite them forever.
  final Set<int> _metadataUnavailableShowIds = {};
  String? _watchedUid;
  final Map<int, DateTime> _failedShowIds = {};

  final _failureController = StreamController<Failure>.broadcast();
  Stream<Failure> get failureStream => _failureController.stream;

  TvShowWatchlistCubit({
    required this.tvWatchlistRepository,
    this.tmdbClient,
  }) : super(TvShowWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(TvShowWatchlistLoading());
    _watchlistSubscription?.cancel();
    if (uid != _watchedUid) {
      _metadataUnavailableShowIds.clear();
      _watchedUid = uid;
    }

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

            // Start backfilling in the background sequentially to avoid socket rate limiting
            _backfillMissingMetadata(uid, mappedShows);
          },
          onError: (error) {
            emit(TvShowWatchlistError(error.toString()));
          },
        );
  }

  // Sequential backfiller that manages lock set and delays requests
  Future<void> _backfillMissingMetadata(
    String uid,
    List<Map<String, dynamic>> shows,
  ) async {
    if (tmdbClient == null) return;

    // Prioritize watched shows first so user's Cinema Passport updates quickly
    final sortedShows = List<Map<String, dynamic>>.from(shows)
      ..sort((a, b) {
        final aWatched = ((a['watchedEpisodes'] as List?)?.isNotEmpty == true ||
                a['category'] == 'FINISHED')
            ? 1
            : 0;
        final bWatched = ((b['watchedEpisodes'] as List?)?.isNotEmpty == true ||
                b['category'] == 'FINISHED')
            ? 1
            : 0;
        return bWatched.compareTo(aWatched);
      });

    final now = DateTime.now();
    for (final show in sortedShows) {
      if (isClosed) break;
      final country = show['origin_country'];
      final lang = show['original_language'];
      final missingCountry = country == null ||
          (country is String && country.isEmpty) ||
          (country is List && country.isEmpty);
      final missingLang = lang == null ||
          (lang is String && lang.isEmpty);

      if (missingCountry || missingLang) {
        final showId = (show['id'] as num?)?.toInt();
        if (showId != null) {
          if (_backfillingShowIds.contains(showId)) continue;
          if (_metadataUnavailableShowIds.contains(showId)) continue;
          final failedAt = _failedShowIds[showId];
          if (failedAt != null &&
              now.difference(failedAt).inMinutes < 5) {
            continue;
          }

          _backfillingShowIds.add(showId);
          try {
            await _fillMissingMetadata(uid, showId, show);
            _failedShowIds.remove(showId);
            // Throttle requests (250ms delay) to prevent TMDb API/Cloudflare connection resets
            await Future.delayed(const Duration(milliseconds: 250));
          } catch (_) {
            _failedShowIds[showId] = DateTime.now();
          } finally {
            _backfillingShowIds.remove(showId);
          }
        }
      }
    }
  }

  Future<void> _fillMissingMetadata(
    String uid,
    int showId,
    Map<String, dynamic> show,
  ) async {
    try {
      if (tmdbClient == null) return;
      final details = await tmdbClient!.getTvShowDetails(showId);
      final countries = details['origin_country'] as List<dynamic>?;
      final originCountry = (countries != null && countries.isNotEmpty)
          ? countries
          : (details['production_countries'] as List<dynamic>?)
              ?.map((c) => (c as Map<String, dynamic>)['iso_3166_1']?.toString())
              .whereType<String>()
              .toList();
      final originalLanguage = details['original_language'] as String?;

      // Write only values that exist and differ from what's stored; an empty
      // result would still read as "missing" and be fetched again.
      final enrichmentData = <String, dynamic>{
        if (originCountry != null &&
            originCountry.isNotEmpty &&
            show['origin_country']?.toString() != originCountry.toString())
          'origin_country': originCountry,
        if (originalLanguage != null &&
            originalLanguage.isNotEmpty &&
            show['original_language'] != originalLanguage)
          'original_language': originalLanguage,
      };

      if (enrichmentData.isNotEmpty) {
        await tvWatchlistRepository.updateShowEnrichment(
          uid: uid,
          showId: showId,
          enrichmentData: enrichmentData,
        );
      }

      // Recorded only after a successful write, so a failed update is retried,
      // and only if this task's user is still the one being watched.
      final stillMissingCountry = originCountry == null || originCountry.isEmpty;
      final stillMissingLang = originalLanguage == null || originalLanguage.isEmpty;
      if (uid == _watchedUid && (stillMissingCountry || stillMissingLang)) {
        _metadataUnavailableShowIds.add(showId);
      }
    } catch (e) {
      debugPrint('Error filling missing metadata for show $showId: $e');
      rethrow;
    }
  }

  Future<void> addShow({
    required String uid,
    required int showId,
    required String name,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double voteAverage,
    dynamic originCountry,
    String? originalLanguage,
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
        originCountry: originCountry,
        originalLanguage: originalLanguage,
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
    _backfillingShowIds.clear();
    _failedShowIds.clear();
    _metadataUnavailableShowIds.clear();
    _watchedUid = null;
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
