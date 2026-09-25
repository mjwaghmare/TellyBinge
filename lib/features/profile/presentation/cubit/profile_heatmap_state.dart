import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';

abstract class ProfileHeatmapState extends Equatable {
  const ProfileHeatmapState();

  @override
  List<Object?> get props => [];
}

class ProfileHeatmapInitial extends ProfileHeatmapState {}

class ProfileHeatmapLoading extends ProfileHeatmapState {}

class ProfileHeatmapLoaded extends ProfileHeatmapState {
  final Map<DateTime, int> tvCounts;
  final Map<DateTime, int> movieCounts;
  final DateTime selectedMonth;

  const ProfileHeatmapLoaded({
    required this.tvCounts,
    required this.movieCounts,
    required this.selectedMonth,
  });

  @override
  List<Object?> get props => [tvCounts, movieCounts, selectedMonth];
}

class ProfileHeatmapError extends ProfileHeatmapState {
  final Failure failure;
  String get message => failure.message;

  ProfileHeatmapError(Object error)
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure];
}
