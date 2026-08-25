import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/profile_activity_repository.dart';

class ProfileActivityRepositoryImpl implements ProfileActivityRepository {
  final FirebaseFirestore _firestore;

  ProfileActivityRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<({Map<DateTime, int> tvCounts, Map<DateTime, int> movieCounts})>
  getMonthActivity({required String uid, required DateTime month}) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final nextMonth = month.month == 12
        ? DateTime(month.year + 1, 1, 1)
        : DateTime(month.year, month.month + 1, 1);
    final endOfMonth = nextMonth.subtract(const Duration(milliseconds: 1));

    final startStr = startOfMonth.toIso8601String();
    final endStr = endOfMonth.toIso8601String();

    final tvSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .where('watchedAt', isGreaterThanOrEqualTo: startStr)
        .where('watchedAt', isLessThanOrEqualTo: endStr)
        .get();

    final moviesSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .where('watchedAt', isGreaterThanOrEqualTo: startStr)
        .where('watchedAt', isLessThanOrEqualTo: endStr)
        .get();

    final Map<DateTime, int> tvCounts = {};
    final Map<DateTime, int> movieCounts = {};

    for (var doc in tvSnapshot.docs) {
      final data = doc.data();
      final watchedAtStr = data['watchedAt'] as String?;
      if (watchedAtStr != null) {
        final watchedAt = DateTime.tryParse(watchedAtStr);
        if (watchedAt != null) {
          final dateKey = DateTime(
            watchedAt.year,
            watchedAt.month,
            watchedAt.day,
          );
          tvCounts[dateKey] = (tvCounts[dateKey] ?? 0) + 1;
        }
      }
    }

    for (var doc in moviesSnapshot.docs) {
      final data = doc.data();
      final isWatched = data['isWatched'] as bool? ?? false;
      if (!isWatched) continue;

      final watchedAtStr = data['watchedAt'] as String?;
      if (watchedAtStr != null) {
        final watchedAt = DateTime.tryParse(watchedAtStr);
        if (watchedAt != null) {
          final dateKey = DateTime(
            watchedAt.year,
            watchedAt.month,
            watchedAt.day,
          );
          movieCounts[dateKey] = (movieCounts[dateKey] ?? 0) + 1;
        }
      }
    }

    return (tvCounts: tvCounts, movieCounts: movieCounts);
  }
}
