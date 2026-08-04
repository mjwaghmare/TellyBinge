import 'dart:async';
import 'dart:collection';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tmdb_client.dart';

/// Pill rendered over a TV poster in the search grid.
enum TvStatusLabel { ended, cancelled, upcoming }

/// Resolves TV show statuses for the search grid.
///
/// A show's status only exists on TMDB's `/tv/{id}` detail endpoint — the
/// trending, discover and search list responses do not carry it — so showing
/// the pill costs one request per show no matter how it is arranged.
///
/// What matters is *where* that cost lands. Previously each tile fetched its
/// own status from `initState`, which put file I/O and an isolate spawn (via
/// the cache layer) on the scroll path, once per tile, with no concurrency
/// limit and no dedup for a tile scrolled away and back.
///
/// Here the cubit owns the work instead: ids are queued when a page of results
/// arrives, resolved a few at a time off the scroll path, and published as a
/// plain map. Results are cached to disk by [TmdbClient], so a given show is
/// fetched once ever. Tiles become a pure map lookup with no I/O of their own.
class TvStatusCubit extends Cubit<Map<int, TvStatusLabel?>> {
  TvStatusCubit({required this.tmdbClient}) : super(const {});

  final TmdbClient tmdbClient;

  /// Keeps detail fetches from saturating the connection pool and starving the
  /// page request the user is actually waiting on.
  static const int _maxConcurrent = 4;

  /// Resolutions land one at a time. Coalescing them into a single emit stops a
  /// page load from triggering one grid rebuild per show.
  static const Duration _emitInterval = Duration(milliseconds: 200);

  /// Resolved ids. A null value means "resolved, no pill to show" — distinct
  /// from an absent key, which means "not looked up yet".
  final Map<int, TvStatusLabel?> _resolved = {};

  final Queue<int> _queue = Queue<int>();
  final Set<int> _queued = {};
  int _active = 0;
  Timer? _emitTimer;

  /// Queues every id that is not already resolved or in flight.
  ///
  /// Safe to call with the whole visible list on each page load — ids already
  /// known or queued are skipped, so only the newly appended page does work.
  void resolveAll(Iterable<int> ids) {
    var added = false;
    for (final id in ids) {
      if (_resolved.containsKey(id) || !_queued.add(id)) continue;
      _queue.add(id);
      added = true;
    }
    if (added) _pump();
  }

  void _pump() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final id = _queue.removeFirst();
      _active++;
      _resolve(id).whenComplete(() {
        _active--;
        if (!isClosed) _pump();
      });
    }
  }

  Future<void> _resolve(int id) async {
    TvStatusLabel? label;
    try {
      final details = await tmdbClient.getTvShowDetails(id);
      label = labelForStatus(details['status'] as String?);
    } catch (_) {
      // Record the failure so a transient error does not re-queue forever.
      label = null;
    }
    if (isClosed) return;
    _resolved[id] = label;
    _queued.remove(id);
    _scheduleEmit();
  }

  void _scheduleEmit() {
    if (_emitTimer?.isActive ?? false) return;
    _emitTimer = Timer(_emitInterval, () {
      if (isClosed) return;
      emit(Map<int, TvStatusLabel?>.unmodifiable(_resolved));
    });
  }

  static TvStatusLabel? labelForStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'ended':
        return TvStatusLabel.ended;
      case 'canceled':
      case 'cancelled':
        return TvStatusLabel.cancelled;
      case 'planned':
      case 'in production':
      case 'post production':
        return TvStatusLabel.upcoming;
      default:
        return null;
    }
  }

  @override
  Future<void> close() {
    _emitTimer?.cancel();
    return super.close();
  }
}
