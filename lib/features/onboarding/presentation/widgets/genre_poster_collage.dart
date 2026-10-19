import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_storage_keys.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/cubit/settings_cubit.dart';
import '../../data/onboarding_storage.dart';

/// Single poster item for the genre matching collage.
class MatchingPosterItem {
  final String assetPath;
  final String title;
  final String genre;

  const MatchingPosterItem({
    required this.assetPath,
    required this.title,
    required this.genre,
  });
}

/// The 12 distinct show posters matching the reference screenshot exactly.
const List<MatchingPosterItem> kMatchingPosters = [
  // Row 1
  MatchingPosterItem(
    assetPath: 'assets/images/posters/friends.webp',
    title: 'Friends',
    genre: 'Comedy',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/off_campus.webp',
    title: 'Off Campus',
    genre: 'Romance',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/sex_education.webp',
    title: 'Sex Education',
    genre: 'Drama',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/chernobyl.webp',
    title: 'Chernobyl',
    genre: 'History',
  ),

  // Row 2
  MatchingPosterItem(
    assetPath: 'assets/images/posters/vincenzo.webp',
    title: 'Vincenzo',
    genre: 'Crime',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/from.webp',
    title: 'From',
    genre: 'Horror',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/indias_best_dancer.webp',
    title: "India's Best Dancer",
    genre: 'Reality',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/reacher.webp',
    title: 'Reacher',
    genre: 'Action',
  ),

  // Row 3
  MatchingPosterItem(
    assetPath: 'assets/images/posters/money_heist_berlin.webp',
    title: 'Money Heist: Berlin',
    genre: 'Adventure',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/when_life_gives_you_tangerines.webp',
    title: 'When Life Gives You Tangerines',
    genre: 'Family',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/stranger_things.webp',
    title: 'Stranger Things',
    genre: 'Sci-Fi',
  ),
  MatchingPosterItem(
    assetPath: 'assets/images/posters/my_name.webp',
    title: 'My Name',
    genre: 'Thriller',
  ),
];

/// Default genre set applied when user completes or skips onboarding without selections.
const List<String> kDefaultOnboardingGenres = [
  'Action',
  'Sci-Fi',
  'Drama',
  'Comedy',
];

/// Normalizes raw or legacy genre names (e.g. 'Science Fiction' -> 'Sci-Fi') to match [kMatchingPosters].
String normalizePosterGenre(String raw) {
  final clean = raw.trim().toLowerCase();
  if (clean == 'science fiction' || clean == 'sci fi') return 'Sci-Fi';
  for (final poster in kMatchingPosters) {
    if (poster.genre.toLowerCase() == clean) return poster.genre;
  }
  return raw;
}

/// Helper to toggle a poster index in synchronized [selectedIndices] and [selectedGenres] sets.
void togglePosterSelection({
  required int index,
  required Set<int> selectedIndices,
  required Set<String> selectedGenres,
  bool allowEmpty = true,
}) {
  final item = kMatchingPosters[index];
  if (selectedIndices.contains(index)) {
    if (allowEmpty || selectedGenres.length > 1) {
      selectedIndices.remove(index);
      selectedGenres.remove(item.genre);
    }
  } else {
    selectedIndices.add(index);
    selectedGenres.add(item.genre);
  }
}

/// Saves the selected genres during onboarding:
/// 1. Dispatches to [SettingsCubit]
/// 2. Persists to [OnboardingStorage]
/// 3. Marks [AppStorageKeys.pendingOnboardingGenresSync] as true for auth sync
Future<void> saveOnboardingGenres({
  required BuildContext context,
  required Set<String> selectedGenres,
}) async {
  final genresList = selectedGenres.toList();
  final genresToSave =
      genresList.isNotEmpty ? genresList : kDefaultOnboardingGenres;

  final settingsCubit = context.read<SettingsCubit>();
  final prefs = context.read<SharedPreferences>();

  await settingsCubit.setPreferredGenres(genresToSave);
  await OnboardingStorage(prefs).savePreferredGenres(genresToSave);
  await prefs.setBool(AppStorageKeys.pendingOnboardingGenresSync, true);
}

/// Card placement specifications in the 432 × 392 reference space.
/// Vertical padding between rows is reduced to create a tight, seamless collage overlap.
class PosterPlacement {
  final int index;
  final double cx;
  final double cy;
  final double rotation;

  const PosterPlacement({
    required this.index,
    required this.cx,
    required this.cy,
    required this.rotation,
  });
}

const List<PosterPlacement> kPosterPlacements = [
  // Row 0 (Top row)
  PosterPlacement(index: 0, cx: 50.0, cy: 68.0, rotation: -0.025), // Friends
  PosterPlacement(index: 1, cx: 143.0, cy: 66.0, rotation: -0.008), // Off Campus
  PosterPlacement(index: 2, cx: 237.0, cy: 66.0, rotation: 0.008), // Sex Education
  PosterPlacement(index: 3, cx: 330.0, cy: 68.0, rotation: 0.025), // Chernobyl

  // Row 1 (Middle row, ~16px subtle overlap with Row 0)
  PosterPlacement(index: 4, cx: 48.0, cy: 180.0, rotation: -0.025), // Vincenzo
  PosterPlacement(index: 5, cx: 142.0, cy: 178.0, rotation: -0.008), // From
  PosterPlacement(index: 6, cx: 238.0, cy: 178.0, rotation: 0.008), // Dancer
  PosterPlacement(index: 7, cx: 332.0, cy: 180.0, rotation: 0.025), // Reacher

  // Row 2 (Bottom row, ~16px subtle overlap with Row 1)
  PosterPlacement(index: 8, cx: 50.0, cy: 292.0, rotation: -0.025), // Berlin
  PosterPlacement(index: 9, cx: 143.0, cy: 290.0, rotation: -0.008), // Tangerines
  PosterPlacement(index: 10, cx: 237.0, cy: 290.0, rotation: 0.008), // Stranger Things
  PosterPlacement(index: 11, cx: 330.0, cy: 292.0, rotation: 0.025), // My Name
];

/// Painting order: Row 2 (back), then Row 1 (middle), then Row 0 (front).
/// This ensures Row 0 and Row 1's genre badges at the bottom of their cards
/// sit cleanly over the top headroom of the row below them.
const List<int> kBasePaintOrder = [
  // Row 2 (back)
  8, 9, 10, 11,
  // Row 1 (middle)
  4, 5, 6, 7,
  // Row 0 (front)
  0, 1, 2, 3,
];

/// The 12-poster overlapping cluster widget.
class GenrePosterCollage extends StatelessWidget {
  const GenrePosterCollage({
    super.key,
    required this.selectedIndices,
    required this.onToggle,
    this.maxScale = 1.15,
  });

  final Set<int> selectedIndices;
  final ValueChanged<int> onToggle;
  final double maxScale;

  static const double referenceWidth = 380.0;
  static const double referenceHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scaleX = box.maxWidth / referenceWidth;
        final scaleY = box.maxHeight.isFinite
            ? box.maxHeight / referenceHeight
            : scaleX;
        final scale = math.min(scaleX, scaleY).clamp(0.4, maxScale);
        final collageWidth = referenceWidth * scale;
        final collageHeight = referenceHeight * scale;

        final cardWidth = 92.0 * scale;
        final cardHeight = cardWidth * 1.39;

        final sortedIndices = List<int>.from(kBasePaintOrder)
          ..sort((a, b) {
            final aSel = selectedIndices.contains(a);
            final bSel = selectedIndices.contains(b);
            if (aSel == bSel) {
              return kBasePaintOrder.indexOf(a).compareTo(kBasePaintOrder.indexOf(b));
            }
            return aSel ? 1 : -1;
          });

        return Center(
          child: SizedBox(
            width: collageWidth,
            height: collageHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final index in sortedIndices)
                  _buildPosterCard(
                    placement: kPosterPlacements[index],
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    scale: scale,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPosterCard({
    required PosterPlacement placement,
    required double cardWidth,
    required double cardHeight,
    required double scale,
  }) {
    final index = placement.index;
    final item = kMatchingPosters[index];
    final isSelected = selectedIndices.contains(index);

    final left = (placement.cx * scale) - (cardWidth / 2.0);
    final top = (placement.cy * scale) - (cardHeight / 2.0);

    return Positioned(
      key: ValueKey(placement.index),
      left: left,
      top: top,
      width: cardWidth,
      height: cardHeight,
      child: Transform.rotate(
        angle: placement.rotation,
        child: GestureDetector(
          onTap: () {
            unawaited(AppHaptics.selectionClick());
            onToggle(index);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0 * scale),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 7.0 * scale,
                  offset: Offset(0, 2.5 * scale),
                ),
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    blurRadius: 10.0 * scale,
                    spreadRadius: 2.0 * scale,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.0 * scale),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    item.assetPath,
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient scrim at the bottom of the card for the genre badge
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 38.0 * scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Genre name badge
                  Positioned(
                    bottom: 4.0 * scale,
                    left: 2.0 * scale,
                    right: 2.0 * scale,
                    child: Text(
                      item.genre,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5 * scale,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4.0 * scale,
                      right: 4.0 * scale,
                      child: Container(
                        width: 17.0 * scale,
                        height: 17.0 * scale,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12.0 * scale,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
