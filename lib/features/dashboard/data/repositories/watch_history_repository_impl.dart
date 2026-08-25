import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/watch_history_item.dart';
import '../../domain/repositories/watch_history_repository.dart';

class WatchHistoryRepositoryImpl implements WatchHistoryRepository {
  final FirebaseFirestore _firestore;

  WatchHistoryRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<WatchHistoryItem>> watchRecentHistory(
    String uid, {
    int days = 7,
  }) {
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .where('watchedAt', isGreaterThan: cutoffDate)
        .orderBy('watchedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return WatchHistoryItem.fromMap(data);
            }).toList());
  }
}

