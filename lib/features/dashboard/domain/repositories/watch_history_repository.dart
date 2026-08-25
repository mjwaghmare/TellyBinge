import '../models/watch_history_item.dart';

abstract class WatchHistoryRepository {
  Stream<List<WatchHistoryItem>> watchRecentHistory(String uid, {int days = 7});
}

