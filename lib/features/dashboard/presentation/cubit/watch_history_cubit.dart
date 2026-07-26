import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

abstract class WatchHistoryState extends Equatable {
  const WatchHistoryState();

  @override
  List<Object> get props => [];
}

class WatchHistoryInitial extends WatchHistoryState {}

class WatchHistoryLoading extends WatchHistoryState {}

class WatchHistoryLoaded extends WatchHistoryState {
  final List<Map<String, dynamic>> history;

  const WatchHistoryLoaded(this.history);

  @override
  List<Object> get props => [history];
}

class WatchHistoryError extends WatchHistoryState {
  final String message;

  const WatchHistoryError(this.message);

  @override
  List<Object> get props => [message];
}

class WatchHistoryCubit extends Cubit<WatchHistoryState> {
  final FirebaseFirestore _firestore;
  StreamSubscription? _historySubscription;
  String? _currentUid;

  WatchHistoryCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
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
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      
      _historySubscription = _firestore
          .collection('users')
          .doc(_currentUid)
          .collection('history')
          .where('watchedAt', isGreaterThan: sevenDaysAgo)
          .orderBy('watchedAt', descending: false)
          .snapshots()
          .listen(
        (snapshot) {
          if (isClosed) return;
          final history = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          emit(WatchHistoryLoaded(history));
        },
        onError: (e) {
          if (isClosed) return;
          debugPrint('Error listening to history: $e');
          emit(WatchHistoryError(e.toString()));
        },
      );
    } catch (e) {
      if (!isClosed) {
        emit(WatchHistoryError(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    _historySubscription?.cancel();
    return super.close();
  }
}
