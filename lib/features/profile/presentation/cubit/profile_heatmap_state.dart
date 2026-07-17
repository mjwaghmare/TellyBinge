import 'package:equatable/equatable.dart';

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
  final String message;

  const ProfileHeatmapError(this.message);

  @override
  List<Object?> get props => [message];
}
