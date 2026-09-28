import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Represents a user's watch count for a specific country.
class CountryVisit extends Equatable {
  final String code;
  final String name;
  final String flagEmoji;
  final int movieCount;
  final int showCount;

  const CountryVisit({
    required this.code,
    required this.name,
    required this.flagEmoji,
    this.movieCount = 0,
    this.showCount = 0,
  });

  int get totalTitles => movieCount + showCount;

  CountryVisit copyWith({
    String? code,
    String? name,
    String? flagEmoji,
    int? movieCount,
    int? showCount,
  }) {
    return CountryVisit(
      code: code ?? this.code,
      name: name ?? this.name,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      movieCount: movieCount ?? this.movieCount,
      showCount: showCount ?? this.showCount,
    );
  }

  @override
  List<Object?> get props => [code, name, flagEmoji, movieCount, showCount];
}

/// The physical geometric shape of the authentic immigration stamp.
enum PassportStampShape {
  circular,
  roundedRectangle,
  oval,
  hexagonal,
}

/// Represents an authentic collectible passport ink stamp.
class PassportStamp extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String countryCode;
  final String flagEmoji;
  final Color inkColor;
  final double rotationAngle; // Realistic tilt in radians
  final int requiredCount;
  final int currentCount;
  final bool isUnlocked;
  final String? unlockedDate;
  final String description;
  final PassportStampShape shape;
  final String? entryCode;

  const PassportStamp({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.countryCode,
    required this.flagEmoji,
    required this.inkColor,
    required this.rotationAngle,
    required this.requiredCount,
    this.currentCount = 0,
    this.isUnlocked = false,
    this.unlockedDate,
    required this.description,
    this.shape = PassportStampShape.circular,
    this.entryCode,
  });

  double get progress =>
      requiredCount > 0 ? (currentCount / requiredCount).clamp(0.0, 1.0) : 0.0;

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    countryCode,
    flagEmoji,
    inkColor.toARGB32(),
    rotationAngle,
    requiredCount,
    currentCount,
    isUnlocked,
    unlockedDate,
    description,
    shape,
    entryCode,
  ];
}

/// Comprehensive aggregated passport data for the user.
class CinemaPassportData extends Equatable {
  final int totalCountries;
  final int totalTitles;
  final List<CountryVisit> countries;
  final List<PassportStamp> stamps;

  const CinemaPassportData({
    required this.totalCountries,
    required this.totalTitles,
    required this.countries,
    required this.stamps,
  });

  int get unlockedStampsCount => stamps.where((s) => s.isUnlocked).length;
  int get totalStampsCount => stamps.length;

  static const CinemaPassportData empty = CinemaPassportData(
    totalCountries: 0,
    totalTitles: 0,
    countries: [],
    stamps: [],
  );

  @override
  List<Object?> get props => [totalCountries, totalTitles, countries, stamps];
}
