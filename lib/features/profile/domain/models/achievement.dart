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

  /// For multi-tier badges, maps each tier to its required threshold.
  final Map<AchievementTier, int>? tierTargets;

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
    this.tierTargets,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  bool get hasTiers => tierTargets != null && tierTargets!.isNotEmpty;

  /// Returns true if this is a multi-tier achievement and the highest tier has been reached.
  bool get isMaxTier {
    if (!hasTiers || tier == AchievementTier.none) return false;
    final maxEntry = tierTargets!.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return tier == maxEntry.key;
  }

  /// The next tier to unlock, or null if already at max tier or not a multi-tier achievement.
  AchievementTier? get nextTier {
    if (!hasTiers) return null;
    final candidates =
        tierTargets!.entries.where((e) => e.value > currentValue);
    if (candidates.isEmpty) return null;
    return candidates.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  /// Target value for the next tier.
  int? get nextTierTarget {
    final next = nextTier;
    return next != null ? tierTargets![next] : null;
  }

  Achievement copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    AchievementTier? tier,
    Map<AchievementTier, int>? tierTargets,
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
      tierTargets: tierTargets ?? this.tierTargets,
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
    tierTargets,
  ];
}
