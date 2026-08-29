import 'package:equatable/equatable.dart';
import '../../domain/models/achievement.dart';

abstract class AchievementsState extends Equatable {
  const AchievementsState();

  @override
  List<Object?> get props => [];
}

class AchievementsInitial extends AchievementsState {}

class AchievementsLoaded extends AchievementsState {
  final List<Achievement> achievements;
  final AchievementCategory? activeFilter;

  const AchievementsLoaded({
    required this.achievements,
    this.activeFilter,
  });

  int get unlockedCount =>
      achievements.where((a) => a.isUnlocked).length;

  int get totalCount => achievements.length;

  List<Achievement> get filtered => activeFilter == null
      ? achievements
      : achievements
            .where((a) => a.category == activeFilter)
            .toList();

  AchievementsLoaded copyWith({
    List<Achievement>? achievements,
    AchievementCategory? Function()? activeFilter,
  }) {
    return AchievementsLoaded(
      achievements: achievements ?? this.achievements,
      activeFilter:
          activeFilter != null ? activeFilter() : this.activeFilter,
    );
  }

  @override
  List<Object?> get props => [achievements, activeFilter];
}
