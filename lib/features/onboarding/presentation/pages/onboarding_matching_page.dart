import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_storage_keys.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/cubit/settings_cubit.dart';
import '../../data/onboarding_storage.dart';

/// Card model for the 12 posters shown in the onboarding matching screen.
class _MatchingPosterItem {
  final String assetPath;
  final String title;
  final String genre;

  const _MatchingPosterItem({
    required this.assetPath,
    required this.title,
    required this.genre,
  });
}

/// Placement spec for an overlapping poster card within the 432 × 509 reference canvas.
class _PosterPlacement {
  final int index;
  final double cx;
  final double cy;
  final double rotation; // in radians

  const _PosterPlacement({
    required this.index,
    required this.cx,
    required this.cy,
    required this.rotation,
  });
}

/// The 12 distinct show posters matching the reference screenshot exactly.
const List<_MatchingPosterItem> _kMatchingPosters = [
  // Row 1
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/friends.webp',
    title: 'Friends',
    genre: 'Comedy',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/off_campus.webp',
    title: 'Off Campus',
    genre: 'Romance',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/sex_education.webp',
    title: 'Sex Education',
    genre: 'Drama',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/chernobyl.webp',
    title: 'Chernobyl',
    genre: 'History',
  ),

  // Row 2
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/vincenzo.webp',
    title: 'Vincenzo',
    genre: 'Crime',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/from.webp',
    title: 'From',
    genre: 'Horror',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/indias_best_dancer.webp',
    title: "India's Best Dancer",
    genre: 'Reality',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/reacher.webp',
    title: 'Reacher',
    genre: 'Action',
  ),

  // Row 3
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/money_heist_berlin.webp',
    title: 'Money Heist: Berlin',
    genre: 'Adventure',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/when_life_gives_you_tangerines.webp',
    title: 'When Life Gives You Tangerines',
    genre: 'Family',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/stranger_things.webp',
    title: 'Stranger Things',
    genre: 'Sci-Fi',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/my_name.webp',
    title: 'My Name',
    genre: 'Thriller',
  ),
];

/// Card placement specifications in the 432 × 509 reference space.
const List<_PosterPlacement> _kPosterPlacements = [
  // Row 0
  _PosterPlacement(index: 0, cx: 58.0, cy: 88.0, rotation: -0.052),
  _PosterPlacement(index: 1, cx: 155.0, cy: 82.0, rotation: -0.014),
  _PosterPlacement(index: 2, cx: 256.0, cy: 82.0, rotation: 0.014),
  _PosterPlacement(index: 3, cx: 355.0, cy: 88.0, rotation: 0.052),

  // Row 1
  _PosterPlacement(index: 4, cx: 52.0, cy: 225.0, rotation: -0.052),
  _PosterPlacement(index: 5, cx: 150.0, cy: 222.0, rotation: -0.014),
  _PosterPlacement(index: 6, cx: 254.0, cy: 222.0, rotation: 0.014),
  _PosterPlacement(index: 7, cx: 358.0, cy: 225.0, rotation: 0.052),

  // Row 2
  _PosterPlacement(index: 8, cx: 56.0, cy: 375.0, rotation: -0.052),
  _PosterPlacement(index: 9, cx: 152.0, cy: 380.0, rotation: -0.014),
  _PosterPlacement(index: 10, cx: 258.0, cy: 378.0, rotation: 0.014),
  _PosterPlacement(index: 11, cx: 358.0, cy: 372.0, rotation: 0.052),
];

/// Natural bottom-to-top painting order matching the reference screenshot collage:
/// - Berlin (under Vincenzo and Tangerines)
/// - Vincenzo (under Friends and From)
/// - Friends (under Off Campus)
/// - My Name (under Reacher and Stranger Things)
/// - Stranger Things (under Dancer and Tangerines)
/// - Dancer (under Sex Ed and From)
/// - Off Campus (under Sex Ed)
/// - Sex Education (under Chernobyl)
/// - Reacher (under Chernobyl)
/// - Chernobyl
/// - Tangerines (front layer in row 2)
/// - From (front layer in center)
const List<int> _kBasePaintOrder = [
  8,  // Berlin
  4,  // Vincenzo
  0,  // Friends
  11, // My Name
  10, // Stranger Things
  6,  // India's Best Dancer
  1,  // Off Campus
  2,  // Sex Education
  7,  // Reacher
  3,  // Chernobyl
  9,  // Tangerines
  5,  // From
];

/// Onboarding genre selection screen matching the reference collage screenshot.
///
/// Features:
/// - Pure black background (#000000)
/// - Top-left translucent circular (X) close/skip button
/// - 12 overlapping poster cards arranged in an organic collage with depth shadows
/// - Interactive genre toggle: selected cards display Electric Violet border, glow,
///   checkmark badge, and are elevated to ensure full visibility
/// - Clear headline: "What do you love to watch?"
/// - Real-time subtitle: count of selected genres
/// - Sleek full-width "Continue" primary button to advance only on user action
class OnboardingMatchingPage extends StatefulWidget {
  const OnboardingMatchingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingMatchingPage> createState() => _OnboardingMatchingPageState();
}

class _OnboardingMatchingPageState extends State<OnboardingMatchingPage> {
  final Set<String> _selectedGenres = {'Comedy', 'Drama', 'Action', 'Sci-Fi'};
  final Set<int> _selectedPosterIndices = {0, 2, 7, 10}; // Friends, Sex Education, Reacher, Stranger Things
  bool _hasFinished = false;

  Future<void> _finish() async {
    if (_hasFinished) return;
    _hasFinished = true;

    final genresList = _selectedGenres.toList();
    final genresToSave = genresList.isNotEmpty
        ? genresList
        : const ['Action', 'Sci-Fi', 'Drama', 'Comedy'];

    if (mounted) {
      await context.read<SettingsCubit>().setPreferredGenres(genresToSave);
      if (!mounted) return;
      final prefs = context.read<SharedPreferences>();
      await OnboardingStorage(prefs).savePreferredGenres(genresToSave);
      await prefs.setBool(AppStorageKeys.pendingOnboardingGenresSync, true);
    }

    widget.onFinished();
  }

  void _togglePoster(int index) {
    unawaited(AppHaptics.selectionClick());
    final item = _kMatchingPosters[index];
    setState(() {
      if (_selectedPosterIndices.contains(index)) {
        _selectedPosterIndices.remove(index);
        _selectedGenres.remove(item.genre);
      } else {
        _selectedPosterIndices.add(index);
        _selectedGenres.add(item.genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Close/Skip (X) button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        unawaited(AppHaptics.lightImpact());
                        _finish();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42.0,
                        height: 42.0,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x26FFFFFF),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 12 Overlapping Poster Cards Collage inside Expanded
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final scaleX = box.maxWidth / 432.0;
                        final scaleY = box.maxHeight / 509.0;
                        final scale = math.min(scaleX, scaleY).clamp(0.4, 1.15);
                        final collageWidth = 432.0 * scale;
                        final collageHeight = 509.0 * scale;

                        return _buildOverlappingCluster(
                          collageWidth: collageWidth,
                          collageHeight: collageHeight,
                          scale: scale,
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Bottom Action Section (Headline, Subtitle, Continue Button)
              const SizedBox(height: 8.0),
              _buildBottomSection(),
              const SizedBox(height: 18.0),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the 12 overlapping posters in the calculated canvas area.
  Widget _buildOverlappingCluster({
    required double collageWidth,
    required double collageHeight,
    required double scale,
  }) {
    final cardWidth = 118.0 * scale;
    final cardHeight = cardWidth * 1.42;

    // Sort render order so selected cards appear on top of unselected cards,
    // ensuring their Electric Violet selection border and checkmark are crisp and visible.
    final sortedIndices = List<int>.from(_kBasePaintOrder)
      ..sort((a, b) {
        final aSel = _selectedPosterIndices.contains(a);
        final bSel = _selectedPosterIndices.contains(b);
        if (aSel == bSel) {
          return _kBasePaintOrder.indexOf(a).compareTo(_kBasePaintOrder.indexOf(b));
        }
        return aSel ? 1 : -1;
      });

    return SizedBox(
      width: collageWidth,
      height: collageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final index in sortedIndices)
            _buildPosterCard(
              placement: _kPosterPlacements[index],
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              scale: scale,
            ),
        ],
      ),
    );
  }

  Widget _buildPosterCard({
    required _PosterPlacement placement,
    required double cardWidth,
    required double cardHeight,
    required double scale,
  }) {
    final index = placement.index;
    final item = _kMatchingPosters[index];
    final isSelected = _selectedPosterIndices.contains(index);

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
          onTap: () => _togglePoster(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0 * scale),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 10.0 * scale,
                  offset: Offset(0, 3.0 * scale),
                ),
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    blurRadius: 12.0 * scale,
                    spreadRadius: 2.0 * scale,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5 * scale),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    item.assetPath,
                    fit: BoxFit.cover,
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6.0 * scale,
                      right: 6.0 * scale,
                      child: Container(
                        width: 20.0 * scale,
                        height: 20.0 * scale,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14.0 * scale,
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

  Widget _buildBottomSection() {
    final count = _selectedGenres.length;
    final subtitle = count == 0
        ? 'Select shows to personalize your recommendations'
        : '$count ${count == 1 ? 'genre' : 'genres'} selected • Tap to adjust';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Headline: "What do you love to watch?"
          Text(
            'What do you love to watch?',
            style: AppTextStyles.xl.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22.0,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6.0),

          // Subtitle showing selected genre count
          Text(
            subtitle,
            style: AppTextStyles.smMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14.0,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 18.0),

          // Prominent "Continue" Button
          SizedBox(
            width: double.infinity,
            height: 52.0,
            child: ElevatedButton(
              onPressed: () {
                unawaited(AppHaptics.lightImpact());
                _finish();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
              ),
              child: Text(
                'Continue',
                style: AppTextStyles.mdMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

