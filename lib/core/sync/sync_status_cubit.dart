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

  StreamSubscription<bool>? _moviesSub;
  StreamSubscription<bool>? _tvSub;
  StreamSubscription<bool>? _customListsSub;
  Timer? _justSyncedTimer;

  bool _moviesPending = false;
  bool _tvPending = false;
  bool _listsPending = false;

  SyncStatusCubit({
    required this.movieWatchlistRepository,
    required this.tvWatchlistRepository,
    required this.customListsRepository,
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
    final wasPending = state.hasPendingWrites;

    if (overallPending == wasPending) return;

    if (wasPending && !overallPending) {
      // Transition from pending to synced: show confirmation banner briefly
      _justSyncedTimer?.cancel();
      emit(state.copyWith(hasPendingWrites: false, justSynced: true));
      _justSyncedTimer = Timer(const Duration(seconds: 3), () {
        if (!isClosed) {
          emit(state.copyWith(justSynced: false));
        }
      });
    } else {
      _justSyncedTimer?.cancel();
      emit(state.copyWith(hasPendingWrites: overallPending, justSynced: false));
    }
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
    _justSyncedTimer?.cancel();
    emit(const SyncStatusState());
  }

  @override
  Future<void> close() {
    stopMonitoring();
    return super.close();
  }
}
