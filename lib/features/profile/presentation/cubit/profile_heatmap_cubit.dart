import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/profile_activity_repository_impl.dart';
import '../../domain/repositories/profile_activity_repository.dart';
import 'profile_heatmap_state.dart';

class ProfileHeatmapCubit extends Cubit<ProfileHeatmapState> {
  final ProfileActivityRepository _repository;

  ProfileHeatmapCubit({ProfileActivityRepository? repository})
    : _repository = repository ?? ProfileActivityRepositoryImpl(),
      super(ProfileHeatmapInitial());

  Future<void> loadMonthActivity(String uid, DateTime month) async {
    emit(ProfileHeatmapLoading());
    final startTime = DateTime.now();
    try {
      final activity = await _repository.getMonthActivity(
        uid: uid,
        month: month,
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final remaining = 700 - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      emit(
        ProfileHeatmapLoaded(
          tvCounts: activity.tvCounts,
          movieCounts: activity.movieCounts,
          selectedMonth: month,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading heatmap: $e');
      debugPrint(stackTrace.toString());
      emit(ProfileHeatmapError(e.toString()));
    }
  }
}

