import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/genre_poster_collage.dart';

/// Standalone genre matching page with 12 overlapping posters and manual Continue button.
class OnboardingMatchingPage extends StatefulWidget {
  const OnboardingMatchingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingMatchingPage> createState() => _OnboardingMatchingPageState();
}

class _OnboardingMatchingPageState extends State<OnboardingMatchingPage> {
  final Set<int> _selectedPosterIndices = {};
  final Set<String> _selectedGenres = {};


  Future<void> _finish() async {
    if (mounted) {
      await saveOnboardingGenres(
        context: context,
        selectedGenres: _selectedGenres,
      );
    }
    if (mounted) {
      widget.onFinished();
    }
  }

  void _togglePoster(int index) {
    setState(() {
      togglePosterSelection(
        index: index,
        selectedIndices: _selectedPosterIndices,
        selectedGenres: _selectedGenres,
      );
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: GenrePosterCollage(
                    selectedIndices: _selectedPosterIndices,
                    onToggle: _togglePoster,
                  ),
                ),
              ),

              // Bottom Action Section (Headline, Subtitle, Continue Button)
              const SizedBox(height: 6.0),
              _buildBottomSection(),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final count = _selectedGenres.length;
    final subtitle = count == 0
        ? 'Pick shows you like to customize your feed'
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

          const SizedBox(height: 4.0),

          // Subtitle showing selected genre count
          Text(
            subtitle,
            style: AppTextStyles.smMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14.0,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16.0),

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
