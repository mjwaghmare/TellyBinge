import 'dart:developer';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    log('Background Task Executed: $task');
    try {
      if (task == 'sync_watchlist_dates') {
        // Here we would ideally:
        // 1. Fetch current watchlist from SharedPreferences or Firestore
        // 2. Query TMDB for updated dates
        // 3. Reschedule local notifications via NotificationService
        
        // For now, returning true to acknowledge task completion.
        log('Sync watchlist dates task completed.');
      }
      return Future.value(true);
    } catch (err) {
      log('Background Task Failed: $err');
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      'sync_watchlist_dates_task_id',
      'sync_watchlist_dates',
      frequency: const Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
