import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/custom_lists/domain/repositories/custom_lists_repository.dart';
import '../../features/dashboard/domain/repositories/tv_watchlist_repository.dart';
import '../../features/movies/domain/repositories/movie_watchlist_repository.dart';
import 'sync_status_state.dart';

class SyncStatusCubit extends Cubit<SyncStatusState> {
  final MovieWatchlistRepository movieWatchlistRepository;
  final TvWatchlistRepository tvWatchlistRepository;
  final CustomListsRepository customListsRepository;

  final Duration pendingDebounceDuration;
  final Duration settleDuration;

  StreamSubscription<bool>? _moviesSub;
  StreamSubscription<bool>? _tvSub;
  StreamSubscription<bool>? _customListsSub;

  Timer? _offlineDebounceTimer;
  Timer? _settleTimer;
  Timer? _justSyncedTimer;

  bool _moviesPending = false;
  bool _tvPending = false;
  bool _listsPending = false;

  SyncStatusCubit({
    required this.movieWatchlistRepository,
    required this.tvWatchlistRepository,
    required this.customListsRepository,
    this.pendingDebounceDuration = const Duration(seconds: 2),
    this.settleDuration = const Duration(milliseconds: 300),
  }) : super(const SyncStatusState());

  void startMonitoring(String uid) {
    stopMonitoring();

    _moviesSub = movieWatchlistRepository
        .watchPendingWrites(uid)
        .listen((pending) => updatePending('movies', pending));

    _tvSub = tvWatchlistRepository
        .watchPendingWrites(uid)
        .listen((pending) => updatePending('tv', pending));

    _customListsSub = customListsRepository
        .watchPendingWrites(uid)
        .listen((pending) => updatePending('lists', pending));
  }

  void updatePending(String source, bool pending) {
    if (source == 'movies') _moviesPending = pending;
    if (source == 'tv') _tvPending = pending;
    if (source == 'lists') _listsPending = pending;

    final overallPending = _moviesPending || _tvPending || _listsPending;

    if (overallPending) {
      _settleTimer?.cancel();
      _settleTimer = null;

      if (!state.hasPendingWrites) {
        if (_offlineDebounceTimer == null || !_offlineDebounceTimer!.isActive) {
          if (pendingDebounceDuration == Duration.zero) {
            _justSyncedTimer?.cancel();
            emit(state.copyWith(hasPendingWrites: true, justSynced: false));
          } else {
            _offlineDebounceTimer = Timer(pendingDebounceDuration, () {
              if (!isClosed) {
                _justSyncedTimer?.cancel();
                emit(state.copyWith(hasPendingWrites: true, justSynced: false));
              }
            });
          }
        }
      }
    } else {
      _offlineDebounceTimer?.cancel();
      _offlineDebounceTimer = null;

      if (state.hasPendingWrites) {
        if (settleDuration == Duration.zero) {
          _emitJustSynced();
        } else {
          _settleTimer?.cancel();
          _settleTimer = Timer(settleDuration, () {
            if (!isClosed) {
              final stillPending =
                  _moviesPending || _tvPending || _listsPending;
              if (!stillPending) {
                _emitJustSynced();
              }
            }
          });
        }
      }
    }
  }

  void _emitJustSynced() {
    _justSyncedTimer?.cancel();
    emit(state.copyWith(hasPendingWrites: false, justSynced: true));
    _justSyncedTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) {
        emit(state.copyWith(justSynced: false));
      }
    });
  }

  void stopMonitoring() {
    _moviesSub?.cancel();
    _tvSub?.cancel();
    _customListsSub?.cancel();
    _moviesSub = null;
    _tvSub = null;
    _customListsSub = null;
    _moviesPending = false;
    _tvPending = false;
    _listsPending = false;
    _offlineDebounceTimer?.cancel();
    _settleTimer?.cancel();
    _justSyncedTimer?.cancel();
    _offlineDebounceTimer = null;
    _settleTimer = null;
    _justSyncedTimer = null;
    emit(const SyncStatusState());
  }

  @override
  Future<void> close() {
    stopMonitoring();
    return super.close();
  }
}
