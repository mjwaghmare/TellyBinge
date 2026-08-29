import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';

/// Clean Notification Model supporting poster, title, episode code, and deep link
class CleanNotificationItem {
  final String id;
  final String title;
  final String? episodeSubtitle;
  final String? posterPath;
  final String? payload;
  final DateTime timestamp;
  final bool isRead;
  final bool isMovie;

  const CleanNotificationItem({
    required this.id,
    required this.title,
    this.episodeSubtitle,
    this.posterPath,
    this.payload,
    required this.timestamp,
    this.isRead = false,
    this.isMovie = false,
  });

  CleanNotificationItem copyWith({
    String? id,
    String? title,
    String? episodeSubtitle,
    String? posterPath,
    String? payload,
    DateTime? timestamp,
    bool? isRead,
    bool? isMovie,
  }) {
    return CleanNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      episodeSubtitle: episodeSubtitle ?? this.episodeSubtitle,
      posterPath: posterPath ?? this.posterPath,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isMovie: isMovie ?? this.isMovie,
    );
  }
}

class SarcasticEmptyState {
  final String emoji;
  final String title;
  final String subtitle;

  const SarcasticEmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<CleanNotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  late SarcasticEmptyState _emptyState;

  static const List<SarcasticEmptyState> _emptyStates = [
    SarcasticEmptyState(
      emoji: '🦗',
      title: 'Crickets in here...',
      subtitle:
          'No notifications yet. Either all your shows are on hiatus or you need to touch some grass.',
    ),
    SarcasticEmptyState(
      emoji: '🍿',
      title: 'Your notifications are empty!',
      subtitle:
          'Empty like your popcorn bucket 5 minutes into the movie. Add some shows to your watchlist!',
    ),
    SarcasticEmptyState(
      emoji: '😴',
      title: 'Total radio silence',
      subtitle:
          'No pushed episodes, no movie premieres, zero drama. Go rewatch The Office for the 14th time.',
    ),
    SarcasticEmptyState(
      emoji: '🛋️',
      title: 'Suspiciously peaceful...',
      subtitle:
          'No cliffhangers waiting to ruin your sleep tonight. Enjoy the quiet while it lasts!',
    ),
    SarcasticEmptyState(
      emoji: '😱',
      title: 'Nothing to report! Go outside?',
      subtitle:
          'Your notification tray is clear. You could actually do something productive... or find new shows.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _emptyState = _emptyStates[Random().nextInt(_emptyStates.length)];
    _fetchReceivedNotifications();
  }

  Future<void> _fetchReceivedNotifications({bool isRefresh = false}) async {
    // Read in-memory watchlist data before async call to populate real posters
    final tvState = context.read<TvShowWatchlistCubit>().state;
    final movieState = context.read<MovieWatchlistCubit>().state;
    final showsList = tvState is TvShowWatchlistSuccess ? tvState.shows : <Map<String, dynamic>>[];
    final moviesList = movieState is MovieWatchlistSuccess ? movieState.movies : <Map<String, dynamic>>[];

    setState(() {
      if (!isRefresh) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final rawItems = await NotificationService().getReceivedNotifications();
      final List<CleanNotificationItem> mapped = [];

      // Map real notifications
      for (final raw in rawItems) {
        final payload = raw.payload;
        String? posterPath;
        bool isMovie = false;
        String? episodeSubtitle;

        if (payload != null) {
          if (payload.startsWith('tvtimeapp://show/')) {
            final idStr = payload.replaceFirst('tvtimeapp://show/', '');
            final id = int.tryParse(idStr);
            if (id != null) {
              final show = showsList.firstWhere(
                (s) {
                  final sId = (s['id'] as num?)?.toInt() ??
                      int.tryParse(s['id']?.toString() ?? '');
                  return sId == id;
                },
                orElse: () => <String, dynamic>{},
              );
              posterPath = show['posterPath'] as String?;
            }
          } else if (payload.startsWith('tvtimeapp://movie/')) {
            isMovie = true;
            final idStr = payload.replaceFirst('tvtimeapp://movie/', '');
            final id = int.tryParse(idStr);
            if (id != null) {
              final movie = moviesList.firstWhere(
                (m) {
                  final mId = (m['id'] as num?)?.toInt() ??
                      int.tryParse(m['id']?.toString() ?? '');
                  return mId == id;
                },
                orElse: () => <String, dynamic>{},
              );
              posterPath = movie['posterPath'] as String?;
            }
          }
        }

        // For shows: extract episode subtitle from body (e.g. "Episode S03 | E06 airs tomorrow.")
        if (!isMovie) {
          final epRegex = RegExp(r'S(\d+)[E| |\|]+(\d+)', caseSensitive: false);
          final epMatch = epRegex.firstMatch(raw.body);
          if (epMatch != null) {
            final sNum = epMatch.group(1)?.padLeft(2, '0');
            final eNum = epMatch.group(2)?.padLeft(2, '0');
            final rest = raw.body.substring(epMatch.end).trim();
            if (rest.isNotEmpty) {
              episodeSubtitle = 'Episode S$sNum | E$eNum $rest';
            } else {
              episodeSubtitle = 'Episode S$sNum | E$eNum';
            }
          } else if (raw.body.isNotEmpty) {
            episodeSubtitle = raw.body;
          }
        }

        DateTime dt;
        try {
          dt = DateTime.parse(raw.timestamp);
        } catch (_) {
          dt = DateTime.now();
        }

        // Clean leading emojis from title
        String cleanTitle = raw.title.replaceAll(RegExp(r'^[^\w\s]+'), '').trim();
        if (cleanTitle.isEmpty) cleanTitle = raw.title;

        mapped.add(
          CleanNotificationItem(
            id: raw.id,
            title: cleanTitle,
            episodeSubtitle: episodeSubtitle,
            posterPath: posterPath,
            payload: payload,
            timestamp: dt,
            isRead: false,
            isMovie: isMovie,
          ),
        );
      }

      // Sort newest first
      mapped.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _notifications = mapped;
          _isLoading = false;
          _errorMessage = null;
        });
      }

      try {
        await NotificationService().markNotificationsAsRead();
      } catch (e) {
        debugPrint('Failed to mark notifications as read: $e');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load notifications. Please try again.';
        });
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isLight = sheetContext.isLight;
        return Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(sheetContext).viewPadding.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Clear All Notifications?',
                style: AppTextStyles.lg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This will remove all alerts from your notification center.',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(
                  color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isLight ? AppColors.borderLight : AppColors.borderDark,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.smMedium.copyWith(
                          color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Clear All',
                        style: AppTextStyles.smBold.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      final previousNotifications = List<CleanNotificationItem>.from(_notifications);
      setState(() {
        _notifications.clear();
        _errorMessage = null;
      });
      try {
        await NotificationService().clearAllUserNotifications();
      } catch (e) {
        if (mounted) {
          setState(() {
            _notifications = previousNotifications;
            _errorMessage = 'Failed to clear notifications. Please try again.';
          });
        }
      }
    }
  }

  void _onNotificationTap(CleanNotificationItem item) {
    HapticFeedback.lightImpact();

    // Mark as read locally
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == item.id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });

    final payload = item.payload;
    if (payload != null && payload.isNotEmpty) {
      if (payload.startsWith('tvtimeapp://show/')) {
        final idStr = payload.replaceFirst('tvtimeapp://show/', '');
        final showId = int.tryParse(idStr);
        if (showId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShowDetailsPage(
                mediaId: showId,
                mediaType: 'tv',
                title: item.title,
              ),
            ),
          );
          return;
        }
      } else if (payload.startsWith('tvtimeapp://movie/')) {
        final idStr = payload.replaceFirst('tvtimeapp://movie/', '');
        final movieId = int.tryParse(idStr);
        if (movieId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsPage(
                movieId: movieId,
                title: item.title,
              ),
            ),
          );
          return;
        }
      }
      NotificationService().onNotificationTap?.call(payload);
    }
  }

  Map<String, List<CleanNotificationItem>> _groupNotificationsByTimeline(
    List<CleanNotificationItem> items,
  ) {
    final Map<String, List<CleanNotificationItem>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    for (final item in items) {
      final itemDate = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );

      String sectionKey;
      if (itemDate.isAtSameMomentAs(today)) {
        sectionKey = 'TODAY';
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        sectionKey = 'YESTERDAY';
      } else if (itemDate.isAfter(thisWeek)) {
        sectionKey = 'THIS WEEK';
      } else {
        sectionKey = 'EARLIER';
      }

      grouped.putIfAbsent(sectionKey, () => []).add(item);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Notifications',
          style: AppTextStyles.xl.copyWith(
            color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: _clearAllNotifications,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Clear all',
                  style: AppTextStyles.smBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _fetchReceivedNotifications(isRefresh: true),
              color: AppColors.primary,
              child: _errorMessage != null
                  ? _buildErrorState(isLight)
                  : _notifications.isEmpty
                      ? _buildEmptyState(isLight)
                      : _buildGroupedListView(_notifications, isLight),
            ),
    );
  }

  Widget _buildGroupedListView(List<CleanNotificationItem> items, bool isLight) {
    final grouped = _groupNotificationsByTimeline(items);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.bottomTabPadding,
      ),
      itemCount: grouped.keys.length,
      itemBuilder: (context, sectionIndex) {
        final sectionKey = grouped.keys.elementAt(sectionIndex);
        final sectionItems = grouped[sectionKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4.0, top: 16.0, bottom: 8.0),
              child: Text(
                sectionKey,
                style: TextStyle(
                  color: isLight ? AppColors.lightTextSecondary : const Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // Section Cards
            ...sectionItems.map((item) => _buildNotificationCard(item, isLight)),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(CleanNotificationItem item, bool isLight) {
    final String? posterFullUrl = item.posterPath != null && item.posterPath!.isNotEmpty
        ? (item.posterPath!.startsWith('http')
            ? item.posterPath!
            : 'https://image.tmdb.org/t/p/w342${item.posterPath}')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNotificationTap(item),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !item.isRead
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : (isLight ? AppColors.borderLight : Colors.white.withValues(alpha: 0.04)),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.02 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact Poster Thumbnail
                _buildPosterThumbnail(posterFullUrl, item.isMovie, isLight),
                const SizedBox(width: 12),

                // Notification Content: Title & Show Episode
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.smBold.copyWith(
                          fontSize: 14.0,
                          color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                        ),
                      ),

                      // Subtitle (show episode) if present
                      if (item.episodeSubtitle != null && item.episodeSubtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2.0),
                        Text(
                          item.episodeSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.xs.copyWith(
                            color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterThumbnail(String? posterUrl, bool isMovie, bool isLight) {
    const double width = 44;
    const double height = 54;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        color: isLight ? const Color(0xFFE5E7EB) : const Color(0xFF1E1E28),
        child: posterUrl != null
            ? CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isLight ? const Color(0xFFE5E7EB) : const Color(0xFF242432),
                ),
                errorWidget: (context, url, error) => _buildPosterFallback(isMovie, isLight),
              )
            : _buildPosterFallback(isMovie, isLight),
      ),
    );
  }

  Widget _buildPosterFallback(bool isMovie, bool isLight) {
    return Center(
      child: Icon(
        isMovie ? Icons.movie_creation_outlined : Icons.live_tv_rounded,
        color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
        size: 20,
      ),
    );
  }


  Widget _buildEmptyState(bool isLight) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _emptyState.emoji,
                    style: const TextStyle(fontSize: 44.0),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _emptyState.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.lg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _emptyState.subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(
                  color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isLight) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54.0, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not load notifications',
                textAlign: TextAlign.center,
                style: AppTextStyles.lg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.xs.copyWith(
                  color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _fetchReceivedNotifications,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

