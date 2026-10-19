import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    genre: 'Comedy',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/chernobyl.webp',
    title: 'Chernobyl',
    genre: 'Drama',
  ),

  // Row 2
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/vincenzo.webp',
    title: 'Vincenzo',
    genre: 'Thriller',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/from.webp',
    title: 'From',
    genre: 'Horror',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/indias_best_dancer.webp',
    title: "India's Best Dancer",
    genre: 'Drama',
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
    genre: 'Action',
  ),
  _MatchingPosterItem(
    assetPath: 'assets/images/posters/when_life_gives_you_tangerines.webp',
    title: 'When Life Gives You Tangerines',
    genre: 'Romance',
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

/// Onboarding matching screen matching the reference screenshot 1:1.
///
/// Features:
/// - Pure black background (#000000)
/// - Top-left translucent circular (X) close button
/// - 12 non-overlapping poster cards arranged in 3 rows × 4 columns
///   with subtle organic barrel curvature and interactive genre toggle
/// - "Finding Matches" bold title
/// - Rolling animated counter ("188 of 1,255 items matched")
/// - Sleek horizontal progress bar filling over ~2.3 seconds
class OnboardingMatchingPage extends StatefulWidget {
  const OnboardingMatchingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingMatchingPage> createState() => _OnboardingMatchingPageState();
}

class _OnboardingMatchingPageState extends State<OnboardingMatchingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _progressAnimation;
  late final Animation<int> _counterAnimation;
  Timer? _completionTimer;

  final Set<String> _selectedGenres = {'Action', 'Sci-Fi', 'Drama', 'Comedy'};
  final Set<int> _selectedPosterIndices = {0, 3, 7, 10}; // Friends, Chernobyl, Reacher, Stranger Things
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _progressAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );

    _counterAnimation = IntTween(begin: 0, end: 188).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _completionTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) unawaited(_finish());
        });
      }
    });
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_hasFinished) return;
    _hasFinished = true;
    _completionTimer?.cancel();
    _animController.stop();

    final genresList = _selectedGenres.toList();
    final genresToSave = genresList.isNotEmpty
        ? genresList
        : const ['Action', 'Sci-Fi', 'Drama', 'Comedy'];

    if (mounted) {
      await context.read<SettingsCubit>().setPreferredGenres(genresToSave);
      if (!mounted) return;
      final prefs = context.read<SharedPreferences>();
      await OnboardingStorage(prefs).savePreferredGenres(genresToSave);
    }

    widget.onFinished();
  }

  void _togglePoster(int index) {
    AppHaptics.selectionClick();
    final item = _kMatchingPosters[index];
    setState(() {
      if (_selectedPosterIndices.contains(index)) {
        _selectedPosterIndices.remove(index);
        // Only remove genre if no other selected poster shares it
        final hasOtherWithGenre = _selectedPosterIndices.any(
          (i) => _kMatchingPosters[i].genre == item.genre,
        );
        if (!hasOtherWithGenre) {
          _selectedGenres.remove(item.genre);
        }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;
              final isCompact = availableHeight < 680;

              const columnSpacing = 6.0;
              const rowSpacing = 6.0;
              final totalHorizontalSpacing = columnSpacing * 3;

              final availablePosterHeight =
                  (availableHeight - (isCompact ? 180.0 : 230.0)).clamp(180.0, 500.0);
              final maxCardHeight = (availablePosterHeight - (rowSpacing * 2)) / 3.0;
              final cardWidthFromHeight = maxCardHeight / 1.42;
              final cardWidthFromWidth =
                  (availableWidth - 32.0 - totalHorizontalSpacing) / 4.0;

              final cardWidth = cardWidthFromWidth < cardWidthFromHeight
                  ? cardWidthFromWidth.clamp(56.0, 92.0)
                  : cardWidthFromHeight.clamp(56.0, 92.0);
              final cardHeight = cardWidth * 1.42;

              return Column(
                children: [
                  // Top Bar with Close (X) button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            AppHaptics.lightImpact();
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

                  if (!isCompact) const Spacer(flex: 1) else const SizedBox(height: 6.0),

                  // 12 Poster Cards (3 Rows × 4 Columns, NON-OVERLAPPING)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildPosterCluster(
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        columnSpacing: columnSpacing,
                        rowSpacing: rowSpacing,
                      ),
                    ),
                  ),

                  if (!isCompact) const Spacer(flex: 2) else const SizedBox(height: 12.0),

                  // Bottom Matching Section
                  _buildBottomMatchingSection(isCompact: isCompact),

                  SizedBox(height: isCompact ? 14.0 : 28.0),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds the 12 posters in 4 columns of 3 rows.
  ///
  /// Designed with deliberate spacing so cards NEVER overlap,
  /// while applying subtle perspective rotation and vertical offset
  /// to capture the organic curved aesthetic from the reference screenshot.
  Widget _buildPosterCluster({
    required double cardWidth,
    required double cardHeight,
    required double columnSpacing,
    required double rowSpacing,
  }) {
    // Group posters by column (4 columns of 3 posters each)
    // Col 0: index 0 (Friends), 4 (Vincenzo), 8 (Berlin)
    // Col 1: index 1 (Off Campus), 5 (From), 9 (Tangerines)
    // Col 2: index 2 (Sex Ed), 6 (Dancer), 10 (Stranger Things)
    // Col 3: index 3 (Chernobyl), 7 (Reacher), 11 (My Name)
    final columns = <List<int>>[
      [0, 4, 8],
      [1, 5, 9],
      [2, 6, 10],
      [3, 7, 11],
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var colIdx = 0; colIdx < 4; colIdx++) ...[
          if (colIdx > 0) SizedBox(width: columnSpacing),
          _buildColumn(
            columnIndices: columns[colIdx],
            colIdx: colIdx,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            rowSpacing: rowSpacing,
          ),
        ],
      ],
    );
  }

  Widget _buildColumn({
    required List<int> columnIndices,
    required int colIdx,
    required double cardWidth,
    required double cardHeight,
    required double rowSpacing,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIdx = 0; rowIdx < columnIndices.length; rowIdx++) ...[
          if (rowIdx > 0) SizedBox(height: rowSpacing),
          _buildPosterCard(
            index: columnIndices[rowIdx],
            colIdx: colIdx,
            rowIdx: rowIdx,
            width: cardWidth,
            height: cardHeight,
          ),
        ],
      ],
    );
  }

  Widget _buildPosterCard({
    required int index,
    required int colIdx,
    required int rowIdx,
    required double width,
    required double height,
  }) {
    final item = _kMatchingPosters[index];
    final isSelected = _selectedPosterIndices.contains(index);

    // Subtle perspective rotation angles & offsets per position to match screenshot
    // Col 0 tilts slightly counter-clockwise, Col 3 tilts clockwise.
    // Center rows arch gently. Spacing guarantees NO overlapping.
    double rotation = 0.0;
    double dy = 0.0;

    switch (colIdx) {
      case 0:
        rotation = rowIdx == 0 ? -0.045 : (rowIdx == 1 ? -0.03 : -0.035);
        dy = rowIdx == 0 ? 3.0 : (rowIdx == 1 ? 0.0 : -3.0);
        break;
      case 1:
        rotation = rowIdx == 0 ? -0.012 : (rowIdx == 1 ? 0.0 : -0.01);
        dy = rowIdx == 0 ? -2.0 : (rowIdx == 1 ? 0.0 : 4.0);
        break;
      case 2:
        rotation = rowIdx == 0 ? 0.012 : (rowIdx == 1 ? 0.0 : 0.01);
        dy = rowIdx == 0 ? -2.0 : (rowIdx == 1 ? 0.0 : 4.0);
        break;
      case 3:
        rotation = rowIdx == 0 ? 0.045 : (rowIdx == 1 ? 0.03 : 0.035);
        dy = rowIdx == 0 ? 3.0 : (rowIdx == 1 ? 0.0 : -3.0);
        break;
    }

    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: rotation,
        child: GestureDetector(
          onTap: () => _togglePoster(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 10.0,
                        spreadRadius: 1.0,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11.8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    item.assetPath,
                    fit: BoxFit.cover,
                  ),
                  if (isSelected)
                    Positioned(
                      top: 5.0,
                      right: 5.0,
                      child: Container(
                        width: 18.0,
                        height: 18.0,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 13.0,
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

  Widget _buildBottomMatchingSection({bool isCompact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title: "Finding Matches"
        Text(
          'Finding Matches',
          style: AppTextStyles.xl.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 22.0 : 24.0,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 6.0),

        // Rolling Counter Subtitle: "188 of 1,255 items matched"
        AnimatedBuilder(
          animation: _counterAnimation,
          builder: (context, _) {
            final count = _counterAnimation.value;
            return Text(
              '$count of 1,255 items matched',
              style: AppTextStyles.smMedium.copyWith(
                color: const Color(0xFF9E9E9E),
                fontSize: isCompact ? 14.0 : 15.0,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),

        SizedBox(height: isCompact ? 16.0 : 26.0),

        // Sleek horizontal progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final fillWidth = totalWidth * _progressAnimation.value;

                  return Container(
                    height: 3.5,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 3.5,
                      width: fillWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
