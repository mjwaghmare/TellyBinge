import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A pure presentation widget that renders a physical-looking, crisp gallery-white
/// Polaroid photograph floating on a colored blurred cinematic canvas.
///
/// Designed to be captured by a [RepaintBoundary] at high resolution for social sharing.
class PolaroidShareCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final double? rating; // 0.0 - 10.0 scale (TMDB or user rating)
  final DateTime? watchedDate;
  final bool showRating;
  final bool showDate;
  final double cardWidth;
  final double tiltX; // Roll (Y-axis 3D rotation)
  final double tiltY; // Pitch (X-axis 3D rotation)
  final bool showBackground; // Whether to render the 9:16 ambient story background canvas
  final ValueChanged<double>? onRatingChanged; // Optional callback when stars are tapped

  const PolaroidShareCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.rating,
    this.watchedDate,
    this.showRating = true,
    this.showDate = true,
    this.cardWidth = 320.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.showBackground = true,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 3D-tilting crisp white Polaroid photo card
    final polaroidContent = Transform(
      alignment: FractionalOffset.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0010) // Subtle, playful 3D perspective depth
        ..rotateY(tiltX) // Gyro roll
        ..rotateX(-tiltY), // Gyro pitch
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: Colors.white, // Crisp gallery-white photo paper
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFE4E4E7).withValues(alpha: 0.8),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.60),
              blurRadius: 36,
              offset: Offset(-tiltX * 24, 18 - tiltY * 24),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: Offset(-tiltX * 12, 5 - tiltY * 12),
            ),
          ],
        ),
        // Classic Polaroid proportions: equal top/sides, tall bottom chin
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vertical Cinematic Photo Still (slightly taller aspect ratio for posters)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AspectRatio(
                aspectRatio: 0.84, // Taller photo area
                child: _buildPhotoImage(),
              ),
            ),

            const SizedBox(height: 12),

            // Wide Bottom Chin Annotations
            _buildPolaroidChin(),
          ],
        ),
      ),
    );

    // If used directly inside an existing blurred screen, render just the polaroid
    if (!showBackground) {
      return Center(child: polaroidContent);
    }

    // 9:16 vertical canvas for social stories export (Instagram Stories, WhatsApp, TikTok)
    final canvasWidth = cardWidth + 60.0;
    final canvasHeight = canvasWidth * (16 / 9);

    return Container(
      width: canvasWidth,
      height: canvasHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Colored Blurred Ambient Background from movie still
          _buildBlurredBackground(),

          // 2. Cinematic dark vignette gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.70),
                ],
              ),
            ),
          ),

          // 3. Floating Crisp White Polaroid with 3D Perspective Motion
          Center(child: polaroidContent),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(color: AppColors.background);
    }

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Transform.scale(
        scale: 1.25, // Prevents edge clipping artifacts from gaussian blur
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => Container(
            color: AppColors.background,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoImage() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(
            Icons.movie_filter_rounded,
            size: 48,
            color: Color(0xFF71717A),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 44,
            color: Color(0xFF71717A),
          ),
        ),
      ),
    );
  }

  Widget _buildPolaroidChin() {
    final hasDate = showDate && watchedDate != null;
    final formattedDate =
        hasDate ? DateFormat('MMM d').format(watchedDate!) : null;

    // Convert 0-10 rating to 0-5 stars
    final double starScore =
        rating != null ? (rating! / 2.0).clamp(0.0, 5.0) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Handwritten Title
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.caveat(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: const Color(0xFF18181B), // Dark ink
          ),
        ),

        const SizedBox(height: 4),

        // Stars + Date row
        if (showRating || hasDate) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showRating)
                _buildStarRow(starScore),
              if (showRating && hasDate)
                const SizedBox(width: 8),
              if (hasDate && formattedDate != null)
                Text(
                  formattedDate,
                  style: GoogleFonts.caveat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3F3F46),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        // Bottom Stamp Row: Clean [ PopVerse 🍿 ] in the bottom right corner
        Align(
          alignment: Alignment.centerRight,
          child: _buildPopVerseStamp(),
        ),
      ],
    );
  }

  Widget _buildStarRow(double score) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final double fill = score - index;
        final IconData icon;
        if (fill >= 0.75) {
          icon = Icons.star_rounded;
        } else if (fill >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }

        final starWidget = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF18181B), // Ink style stars
          ),
        );

        if (onRatingChanged != null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              // 0-10 scale (star 1..5 maps to 2.0..10.0)
              final newRating = (index + 1) * 2.0;
              onRatingChanged!(newRating);
            },
            child: starWidget,
          );
        }

        return starWidget;
      }),
    );
  }

  Widget _buildPopVerseStamp() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF18181B).withValues(alpha: 0.55),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'PopVerse',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: const Color(0xFF18181B),
            ),
          ),
          AppSpacing.gapW4,
          // PopVerse Popcorn App Icon to the right of text (transparent background)
          Image.asset(
            AppAssets.splashLogo,
            width: 14,
            height: 14,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );
  }
}
