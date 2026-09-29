import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/custom_lists/domain/repositories/custom_lists_repository.dart';
import '../../features/dashboard/domain/repositories/tv_watchlist_repository.dart';
import '../../features/movies/domain/repositories/movie_watchlist_repository.dart';
import 'pending_writes.dart';
import 'sync_status_state.dart';

class SyncStatusCubit extends Cubit<SyncStatusState> {
  final MovieWatchlistRepository movieWatchlistRepository;
  final TvWatchlistRepository tvWatchlistRepository;
  final CustomListsRepository customListsRepository;

  final Duration pendingDebounceDuration;

  /// How long writes must stay confirmed before "All changes synced" shows.
  /// Also leaves time for the banner's percentage to count up to 100%.
  final Duration settleDuration;

  StreamSubscription<PendingWrites>? _moviesSub;
  StreamSubscription<PendingWrites>? _tvSub;
  StreamSubscription<PendingWrites>? _customListsSub;

  Timer? _offlineDebounceTimer;
  Timer? _settleTimer;
  Timer? _justSyncedTimer;

  final Map<String, PendingWrites> _sources = {};

  SyncStatusCubit({
    required this.movieWatchlistRepository,
    required this.tvWatchlistRepository,
    required this.customListsRepository,
    this.pendingDebounceDuration = const Duration(seconds: 2),
    this.settleDuration = const Duration(milliseconds: 800),
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

  int get _pendingCount => _sources.values.fold(0, (sum, s) => sum + s.count);

  // One Firestore connection serves every listener, so any server snapshot
  // means the app is online.
  bool get _isOnline => _sources.isEmpty || _sources.values.any((s) => s.isOnline);

  void updatePending(String source, PendingWrites pending) {
    _sources[source] = pending;
    final count = _pendingCount;

    // Newly queued writes grow the total; confirmed ones leave it alone, so
    // progress only moves back when more work arrives mid-sync.
    final added = count - state.pendingCount;
    final syncTotal = state.syncTotal + (added > 0 ? added : 0);
    emit(state.copyWith(pendingCount: count, syncTotal: syncTotal, isOnline: _isOnline));

    if (count > 0) {
      _settleTimer?.cancel();
      _settleTimer = null;

      // The banner only starts while offline. Online, writes confirm within
      // moments, and background upkeep (TMDB enrichment, backfills) would
      // otherwise read as "Syncing". A sync that started offline still runs
      // to 100% after reconnecting.
      if (!state.hasPendingWrites && !_isOnline) {
        if (_offlineDebounceTimer == null || !_offlineDebounceTimer!.isActive) {
          if (pendingDebounceDuration == Duration.zero) {
            _startBanner();
          } else {
            _offlineDebounceTimer = Timer(pendingDebounceDuration, () {
              if (!isClosed && _pendingCount > 0 && !_isOnline) _startBanner();
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
            if (!isClosed && _pendingCount == 0) {
              _emitJustSynced();
            }
          });
        }
      } else {
        // Writes confirmed within the debounce window never showed the
        // banner; start the next sync from zero.
        emit(state.copyWith(syncTotal: 0));
      }
    }
  }

  void _startBanner() {
    _justSyncedTimer?.cancel();
    // Count progress from what is queued now, not from background writes
    // that confirmed while the banner was hidden.
    emit(state.copyWith(hasPendingWrites: true, justSynced: false, syncTotal: _pendingCount));
  }

  void _emitJustSynced() {
    _justSyncedTimer?.cancel();
    emit(state.copyWith(hasPendingWrites: false, justSynced: true, syncTotal: 0));
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
    _sources.clear();
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
