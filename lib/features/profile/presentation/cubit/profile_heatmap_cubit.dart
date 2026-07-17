import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_heatmap_state.dart';
import 'package:flutter/foundation.dart';

class ProfileHeatmapCubit extends Cubit<ProfileHeatmapState> {
  final FirebaseFirestore _firestore;

  ProfileHeatmapCubit({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(ProfileHeatmapInitial());

  Future<void> loadMonthActivity(String uid, DateTime month) async {
    emit(ProfileHeatmapLoading());
    final startTime = DateTime.now();
    try {
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
          .where('addedAt', isGreaterThanOrEqualTo: startStr)
          .where('addedAt', isLessThanOrEqualTo: endStr)
          .get();

      final Map<DateTime, int> tvCounts = {};
      final Map<DateTime, int> movieCounts = {};

      for (var doc in tvSnapshot.docs) {
        final data = doc.data();
        final watchedAtStr = data['watchedAt'] as String?;
        if (watchedAtStr != null) {
          final watchedAt = DateTime.tryParse(watchedAtStr);
          if (watchedAt != null) {
            final dateKey = DateTime(watchedAt.year, watchedAt.month, watchedAt.day);
            tvCounts[dateKey] = (tvCounts[dateKey] ?? 0) + 1;
          }
        }
      }

      for (var doc in moviesSnapshot.docs) {
        final data = doc.data();
        final isWatched = data['isWatched'] as bool? ?? false;
        if (!isWatched) continue;

        final addedAtStr = data['addedAt'] as String?;
        if (addedAtStr != null) {
          final addedAt = DateTime.tryParse(addedAtStr);
          if (addedAt != null) {
            final dateKey = DateTime(addedAt.year, addedAt.month, addedAt.day);
            movieCounts[dateKey] = (movieCounts[dateKey] ?? 0) + 1;
          }
        }
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final remaining = 700 - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      emit(ProfileHeatmapLoaded(
        tvCounts: tvCounts,
        movieCounts: movieCounts,
        selectedMonth: month,
      ));
    } catch (e, stackTrace) {
      debugPrint('Error loading heatmap: $e');
      debugPrint(stackTrace.toString());
      emit(ProfileHeatmapError(e.toString()));
    }
  }
}
