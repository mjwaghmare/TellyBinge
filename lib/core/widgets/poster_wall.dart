import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-bleed grid of TMDb posters, used as the backdrop on the screens an
/// unauthenticated user sees (login, onboarding).
///
/// [posterPaths] are TMDb poster paths (`/abc123.jpg`). They are shuffled once
/// per mount, so the wall looks different each time the screen is reached
/// without reshuffling on every rebuild.
class PosterWall extends StatefulWidget {
  const PosterWall({super.key, required this.posterPaths});

  final List<String> posterPaths;

  @override
  State<PosterWall> createState() => _PosterWallState();
}

class _PosterWallState extends State<PosterWall> {
  static const int _columnCount = 3;

  /// Tile height as a multiple of tile width — standard 2:3 poster artwork.
  static const double _posterAspectRatio = 3 / 2;

  /// How far each column is lifted, as a fraction of one tile height. Staggering
  /// the columns keeps the wall from reading as a plain aligned grid.
  static const List<double> _columnLift = [0.35, 0.05, 0.6];

  /// Enough shuffled passes over the poster list to fill any phone screen
  /// without wrapping, so a repeat never lands next to its twin.
  static const int _shufflePasses = 3;

  static const double _tileRadius = 12.0;

  late final List<String> _tiles;

  @override
  void initState() {
    super.initState();
    final random = Random();
    final tiles = <String>[];
    for (var pass = 0; pass < _shufflePasses; pass++) {
      tiles.addAll(List.of(widget.posterPaths)..shuffle(random));
    }
    _tiles = tiles;
  }

  @override
  Widget build(BuildContext context) {
    if (_tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.xs;
        final tileWidth =
            (constraints.maxWidth - gap * (_columnCount - 1)) / _columnCount;
        final tileHeight = tileWidth * _posterAspectRatio;
        // One extra row beyond the viewport so the lifted columns still reach
        // the bottom edge.
        final rowCount =
            ((constraints.maxHeight + tileHeight) / (tileHeight + gap)).ceil() +
            1;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var column = 0; column < _columnCount; column++)
                for (var row = 0; row < rowCount; row++)
                  Positioned(
                    left: column * (tileWidth + gap),
                    top:
                        row * (tileHeight + gap) -
                        tileHeight * _columnLift[column],
                    width: tileWidth,
                    height: tileHeight,
                    child: _PosterTile(
                      posterPath:
                          _tiles[(column * rowCount + row) % _tiles.length],
                      radius: _tileRadius,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.posterPath, required this.radius});

  final String posterPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: AppConstants.tmdbImageUrl(posterPath, size: 'w342'),
        fit: BoxFit.cover,
        memCacheWidth: 342,
        fadeInDuration: const Duration(milliseconds: 350),
        placeholder: (context, url) => const _PosterPlaceholder(),
        errorWidget: (context, url, error) => const _PosterPlaceholder(),
      ),
    );
  }
}

/// Stands in for a poster that has not downloaded yet — or cannot, because the
/// device is offline on first launch. Tinted rather than flat so an unloaded
/// wall still looks composed instead of broken.
class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceElevated],
        ),
      ),
    );
  }
}
