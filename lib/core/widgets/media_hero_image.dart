import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Banner artwork for the top of a movie/show details page.
///
/// Uses the landscape backdrop when TMDB has one. Many smaller or newer titles
/// don't, so it falls back to the portrait poster blurred to fill the wide
/// frame — a sharp poster cropped to 16:9 would show only a sliver of it — and
/// finally to a plain surface.
///
/// The artwork often changes once after the page opens (the list's backdrop is
/// replaced by the best one from the details response). The outgoing image
/// stays in place and the new one fades in over it only once decoded, so the
/// banner never blanks or jumps.
class MediaHeroImage extends StatefulWidget {
  final String? backdropPath;
  final String? posterPath;
  final String backdropSize;

  const MediaHeroImage({
    super.key,
    this.backdropPath,
    this.posterPath,
    this.backdropSize = 'w780',
  });

  @override
  State<MediaHeroImage> createState() => _MediaHeroImageState();
}

typedef _HeroArt = ({String url, bool blurred});

class _MediaHeroImageState extends State<MediaHeroImage> {
  _HeroArt? _previous;

  _HeroArt? _resolve(MediaHeroImage w) {
    final backdrop = w.backdropPath ?? '';
    if (backdrop.isNotEmpty) {
      return (
        url: AppConstants.tmdbImageUrl(backdrop, size: w.backdropSize),
        blurred: false,
      );
    }
    final poster = w.posterPath ?? '';
    if (poster.isNotEmpty) {
      return (
        url: AppConstants.tmdbImageUrl(poster, size: 'w342'),
        blurred: true,
      );
    }
    return null;
  }

  @override
  void didUpdateWidget(MediaHeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = _resolve(oldWidget);
    if (old != _resolve(widget)) _previous = old;
  }

  @override
  Widget build(BuildContext context) {
    final current = _resolve(widget);
    final previous = _previous;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.surface),
        // Keyed by URL so the element that was "current" is reused here
        // as-is, already decoded and fully opaque.
        if (previous != null && previous != current)
          KeyedSubtree(key: ValueKey(previous), child: _buildArt(previous)),
        if (current != null)
          KeyedSubtree(key: ValueKey(current), child: _buildArt(current)),
      ],
    );
  }

  Widget _buildArt(_HeroArt art) {
    final image = CachedNetworkImage(
      imageUrl: art.url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      // Fade starts when decoded (memory or network alike); a fade keyed to
      // widget creation would reveal an empty frame on a slow load.
      imageBuilder: (context, provider) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Image(image: provider, fit: BoxFit.cover),
      ),
      // Transparent, so a failed swap leaves the previous art (or the base
      // surface) showing instead of blanking the banner.
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );

    if (!art.blurred) return image;
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Transform.scale(
          scale: 1.2, // Keeps the blur's soft edges outside the frame
          child: image,
        ),
      ),
    );
  }
}
