import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/watch_history_repository_impl.dart';
import '../../domain/repositories/watch_history_repository.dart';

import '../../domain/models/watch_history_item.dart';

abstract class WatchHistoryState extends Equatable {
  const WatchHistoryState();

  @override
  List<Object?> get props => [];
}

class WatchHistoryInitial extends WatchHistoryState {}

class WatchHistoryLoading extends WatchHistoryState {}

class WatchHistoryLoaded extends WatchHistoryState {
  final List<WatchHistoryItem> history;

  const WatchHistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class WatchHistoryError extends WatchHistoryState {
  final Failure failure;
  String get message => failure.message;

  WatchHistoryError(Object error)
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure];
}

class WatchHistoryCubit extends Cubit<WatchHistoryState> {
  final WatchHistoryRepository _repository;
  StreamSubscription? _historySubscription;
  String? _currentUid;

  WatchHistoryCubit({WatchHistoryRepository? repository})
    : _repository = repository ?? WatchHistoryRepositoryImpl(),
      super(WatchHistoryInitial());

  void init(String uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;
    _listenToHistory();
  }

  void _listenToHistory() {
    _historySubscription?.cancel();
    if (_currentUid == null) return;

    emit(WatchHistoryLoading());

    try {
      _historySubscription = _repository
          .watchRecentHistory(_currentUid!, days: 7)
          .listen(
            (history) {
              if (isClosed) return;
              emit(WatchHistoryLoaded(history));
            },
            onError: (e) {
              if (isClosed) return;
              debugPrint('Error listening to history: $e');
              emit(WatchHistoryError(Failure.fromException(e)));
            },
          );
    } catch (e) {
      if (!isClosed) {
        emit(WatchHistoryError(Failure.fromException(e)));
      }
    }
  }

  @override
  Future<void> close() {
    _historySubscription?.cancel();
    return super.close();
  }
}
