import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/auth/presentation/cubit/auth_state.dart';
import '../cubit/tv_show_watchlist_cubit.dart';

class WatchedEpisodeCard extends StatefulWidget {
  final Map<String, dynamic> historyEvent;

  const WatchedEpisodeCard({super.key, required this.historyEvent});

  @override
  State<WatchedEpisodeCard> createState() => _WatchedEpisodeCardState();
}

class _WatchedEpisodeCardState extends State<WatchedEpisodeCard> {
  bool _isReverting = false;
  DateTime? _revertStartTime;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(WatchedEpisodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historyEvent != oldWidget.historyEvent) {
      if (_isReverting) {
        _revertTimer?.cancel();
        final elapsed = _revertStartTime != null
            ? DateTime.now().difference(_revertStartTime!)
            : const Duration(milliseconds: 500);
        const minDuration = Duration(milliseconds: 500);
        if (elapsed < minDuration) {
          final remaining = minDuration - elapsed;
          _revertTimer = Timer(remaining, () {
            if (mounted) {
              setState(() {
                _isReverting = false;
                _revertStartTime = null;
              });
            }
          });
        } else {
          setState(() {
            _isReverting = false;
            _revertStartTime = null;
          });
        }
      }
    }
  }

  void _handleUnwatch() async {
    if (_isReverting) return;
    _revertStartTime = DateTime.now();
    setState(() => _isReverting = true);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      context.read<TvShowWatchlistCubit>().toggleEpisodeWatched(
        uid: authState.user.uid,
        showId: widget.historyEvent['showId'] as int,
        episodeKey: widget.historyEvent['episodeKey'] as String,
        isWatched: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posterPath = widget.historyEvent['showPoster'] as String?;
    final imageUrl = (posterPath != null && posterPath.isNotEmpty)
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;

    final showName =
        widget.historyEvent['showName']?.toString().toUpperCase() ?? 'UNKNOWN';

    // Parse episodeKey like "1-4" to "S01 | E04"
    final epKey = widget.historyEvent['episodeKey']?.toString() ?? '';
    String displayCode = epKey;
    if (epKey.contains('-')) {
      final parts = epKey.split('-');
      if (parts.length == 2) {
        final s =
            int.tryParse(parts[0])?.toString().padLeft(2, '0') ?? parts[0];
        final e =
            int.tryParse(parts[1])?.toString().padLeft(2, '0') ?? parts[1];
        displayCode = 'S$s | E$e';
      }
    }

    final episodeTitle = widget.historyEvent['episodeTitle']?.toString() ?? '';

    return Opacity(
      opacity: _isReverting ? 0.3 : 0.6,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        clipBehavior: Clip.antiAlias,
        height: 96.0,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                width: 100,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: context.adaptiveColor(
                            light: Colors.grey[200]!,
                            dark: AppColors.surfaceLight,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: context.adaptiveColor(
                            light: Colors.grey[200]!,
                            dark: AppColors.surfaceLight,
                          ),
                          child: Icon(
                            Icons.tv,
                            color: context.adaptiveColor(
                              light: Colors.grey[500]!,
                              dark: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    : Container(color: AppColors.surfaceLight),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0.0, 16.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Show Name Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white24
                              : Colors.black12,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              showName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Episode Code
                    Text(
                      displayCode,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    // Episode Title
                    Text(
                      episodeTitle.isNotEmpty ? episodeTitle : 'TBA',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondary
                            : Colors.black54,
                        fontSize: 11.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Checkmark
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: GestureDetector(
                  onTap: _handleUnwatch,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen, // TV Time Green
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brandGreen, width: 2),
                    ),
                    child: _isReverting
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.check, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
