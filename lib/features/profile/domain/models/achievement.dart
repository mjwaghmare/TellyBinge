import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Category grouping for achievements.
enum AchievementCategory { volume, habits, genres, streaks, special }

/// Visual tier for multi-level achievements.
enum AchievementTier { none, bronze, silver, gold, diamond }

/// A single achievement definition with its current progress state.
class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final IconData icon;
  final int currentValue;
  final int targetValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  /// Asset path to the badge image in assets/awards/.
  final String assetPath;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.tier = AchievementTier.none,
    required this.icon,
    this.currentValue = 0,
    required this.targetValue,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.assetPath,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  Achievement copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    AchievementTier? tier,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      category: category,
      tier: tier ?? this.tier,
      icon: icon,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      assetPath: assetPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    tier,
    currentValue,
    targetValue,
    isUnlocked,
    unlockedAt,
  ];
}
