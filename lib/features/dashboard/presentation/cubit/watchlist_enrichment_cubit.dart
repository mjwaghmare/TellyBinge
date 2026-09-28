import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../data/repositories/tv_watchlist_repository_impl.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';
import 'watchlist_enrichment_state.dart';

class WatchlistEnrichmentCubit extends Cubit<WatchlistEnrichmentState> {
  final TmdbClient tmdbClient;
  final TvWatchlistRepository _repository;

  WatchlistEnrichmentCubit({
    required this.tmdbClient,
    TvWatchlistRepository? repository,
  }) : _repository = repository ?? TvWatchlistRepositoryImpl(),
       super(WatchlistEnrichmentInitial());

  /// Tracks which show IDs have already been enriched in this session
  /// to avoid redundant TMDB calls when Firestore re-fires after write-back.
  final Set<int> _enrichedShowIds = {};

  /// Tracks which show IDs are currently undergoing background enrichment
  final Set<int> _currentlyEnrichingShowIds = {};

  /// Tracks the watchedEpisodes hash for each show to detect actual changes.
  final Map<int, int> _watchedEpisodesHash = {};

  bool _isRecentlyAired(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      final airDay = DateTime.utc(date.year, date.month, date.day);
      final diff = today.difference(airDay).inDays;
      return diff >= 0 && diff <= 7;
    } catch (_) {
      return false;
    }
  }

  bool _isUpcomingSoon(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);
      final airDay = DateTime.utc(date.year, date.month, date.day);
      final diff = airDay.difference(today).inDays;
      return diff >= 0 && diff <= 7;
    } catch (_) {
      return false;
    }
  }

  /// Computes a simple hash of watched episodes list for change detection.
  int _computeWatchedHash(List<String> episodes) {
    if (episodes.isEmpty) return 0;
    final sorted = List<String>.from(episodes)..sort();
    return sorted.join(',').hashCode;
  }

  /// Checks if a show was enriched recently enough to skip re-enrichment.
  bool _isRecentlyEnriched(Map<String, dynamic> showData) {
    final lastEnrichedStr = showData['lastEnrichedAt'] as String?;
    if (lastEnrichedStr == null || lastEnrichedStr.isEmpty) return false;
    try {
      if (showData['totalEpisodes'] == null) return false;
      if (showData['origin_country'] == null &&
          showData['original_language'] == null) {
        return false;
      }

      // Bypass 6-hour cache if show has an upcoming episode scheduled for today or earlier
      final upcomingAirDateStr = showData['upcomingAirDate'] as String?;
      if (upcomingAirDateStr != null && upcomingAirDateStr.isNotEmpty) {
        final airDate = DateTime.tryParse(upcomingAirDateStr);
        if (airDate != null) {
          final now = DateTime.now();
          final today = DateTime.utc(now.year, now.month, now.day);
          final airDay = DateTime.utc(airDate.year, airDate.month, airDate.day);
          if (!airDay.isAfter(today)) {
            return false;
          }
        }
      }

      final lastEnriched = DateTime.parse(lastEnrichedStr);
      final age = DateTime.now().difference(lastEnriched);
      return age.inHours < 6;
    } catch (_) {
      return false;
    }
  }

  /// Enriches shows by fetching TMDB data and writing results back to Firebase.
  ///
  /// This is a **background operation**. The UI does NOT wait for this — it
  /// renders immediately from the pre-computed fields stored in Firebase.
  ///
  /// Optimizations:
  /// - Skips shows enriched < 6 hours ago (unless watchedEpisodes changed)
  /// - Skips shows already enriched this session with same watchedEpisodes
  /// - Processes in batches of 3 to avoid file descriptor exhaustion
  Future<void> enrichShows(
    List<Map<String, dynamic>> rawShows,
    String uid, {
    bool force = false,
  }) async {
    if (rawShows.isEmpty) return;

    final showsToEnrich = <Map<String, dynamic>>[];

    for (var raw in rawShows) {
      final showId = (raw['id'] as num?)?.toInt();
      if (showId == null) continue;
      if (showId == -1) continue;
      if ((raw['status'] as String?) == 'STOPPED') continue;

      // Skip if already being enriched in an active loop
      if (_currentlyEnrichingShowIds.contains(showId)) {
        continue;
      }

      final watchedEpisodes = List<String>.from(raw['watchedEpisodes'] ?? []);
      final currentHash = _computeWatchedHash(watchedEpisodes);
      final previousHash = _watchedEpisodesHash[showId];

      if (!force) {
        // Skip if already enriched this session with same watchedEpisodes
        if (_enrichedShowIds.contains(showId) && previousHash == currentHash) {
          continue;
        }

        // Skip if enriched recently AND watchedEpisodes hasn't changed
        // (for cross-session staleness — first app open of the day)
        if (_isRecentlyEnriched(raw) && previousHash == currentHash) {
          _enrichedShowIds.add(showId);
          _watchedEpisodesHash[showId] = currentHash;
          continue;
        }
      }

      showsToEnrich.add(raw);
    }

    if (showsToEnrich.isEmpty) return;

    // Prioritize watched shows so Cinema Passport updates quickly
    showsToEnrich.sort((a, b) {
      final aWatched = ((a['watchedEpisodes'] as List?)?.isNotEmpty == true ||
              a['category'] == 'FINISHED')
          ? 1
          : 0;
      final bWatched = ((b['watchedEpisodes'] as List?)?.isNotEmpty == true ||
              b['category'] == 'FINISHED')
          ? 1
          : 0;
      return bWatched.compareTo(aWatched);
    });

    // Queue locks before starting requests
    for (final raw in showsToEnrich) {
      final showId = (raw['id'] as num?)?.toInt();
      if (showId != null) {
        _currentlyEnrichingShowIds.add(showId);
      }
    }

    // Process sequentially to avoid "Connection reset by peer" (errno 54) socket flooding
    try {
      for (final showData in showsToEnrich) {
        if (isClosed) break;
        final showId = (showData['id'] as num?)?.toInt();
        if (showId == null) continue;
        try {
          await _enrichAndWriteBack(showData, uid);
        } finally {
          _currentlyEnrichingShowIds.remove(showId);
        }
        await Future.delayed(
          const Duration(milliseconds: 250),
        ); // Be nice to TMDB API
      }
    } catch (e) {
      debugPrint('WatchlistEnrichmentCubit: Background enrichment error: $e');
    } finally {
      // Safety clean up for any remaining locked IDs (e.g. if loop broke)
      for (final raw in showsToEnrich) {
        final showId = (raw['id'] as num?)?.toInt();
        if (showId != null) {
          _currentlyEnrichingShowIds.remove(showId);
        }
      }
    }
  }

  /// Enriches a single show from TMDB and writes the computed fields
  /// back to the Firestore document.
  ///
  /// Optimized to:
  /// - Only fetch season details for seasons with unwatched episodes
  /// - Cache fetched season details locally to avoid redundant calls
  Future<void> _enrichAndWriteBack(
    Map<String, dynamic> showData,
    String uid,
  ) async {
    final showId = (showData['id'] as num?)?.toInt();
    if (showId == null) return;

    try {
      final details = await tmdbClient.getTvShowDetails(showId);
      final watchedEpisodes = List<String>.from(
        showData['watchedEpisodes'] ?? [],
      );
      final seasons = details['seasons'] as List<dynamic>? ?? [];

      // Build a set of watched episodes for O(1) lookups
      final watchedSet = watchedEpisodes.toSet();

      // --- Pre-compute which seasons have unwatched episodes ---
      // Uses episode_count from show metadata (no API call needed).
      final seasonsWithUnwatched = <int>[];
      for (var season in seasons) {
        final seasonNum = (season['season_number'] as num?)?.toInt() ?? 0;
        if (seasonNum == 0) continue;
        final episodeCount = (season['episode_count'] as num?)?.toInt() ?? 0;

        bool hasUnwatched = false;
        for (int epNum = 1; epNum <= episodeCount; epNum++) {
          if (!watchedSet.contains('$seasonNum-$epNum')) {
            hasUnwatched = true;
            break;
          }
        }
        if (hasUnwatched) {
          seasonsWithUnwatched.add(seasonNum);
        }
      }

      // --- Find next unwatched episode ---
      String nextCode = '';
      String nextTitle = '';
      bool foundNext = false;
      bool isSeriesPremiere = false;
      bool isSeasonPremiere = false;
      int tempTargetSeason = 0;
      int tempTargetEpisode = 0;

      for (var season in seasons) {
        if (foundNext) break;
        final seasonNum = (season['season_number'] as num?)?.toInt() ?? 0;
        if (seasonNum == 0) continue;
        final episodeCount = (season['episode_count'] as num?)?.toInt() ?? 0;

        for (int epNum = 1; epNum <= episodeCount; epNum++) {
          if (!watchedSet.contains('$seasonNum-$epNum')) {
            foundNext = true;
            final sStr = seasonNum.toString().padLeft(2, '0');
            final eStr = epNum.toString().padLeft(2, '0');
            nextCode = 'S$sStr | E$eStr';
            nextTitle = 'Episode $epNum';
            tempTargetSeason = seasonNum;
            tempTargetEpisode = epNum;

            if (seasonNum == 1 && epNum == 1) {
              isSeriesPremiere = true;
            } else if (epNum == 1) {
              isSeasonPremiere = true;
            }
            break;
          }
        }
      }

      int airedUnwatchedCount = 0;
      final now = DateTime.now();
      final today = DateTime.utc(now.year, now.month, now.day);

      // Local cache to avoid fetching the same season twice
      final fetchedSeasons = <int, Map<String, dynamic>>{};

      if (foundNext) {
        // Fetch the target season for the next episode title
        try {
          final seasonDetails = await tmdbClient.getTvSeasonDetails(
            showId,
            tempTargetSeason,
          );
          fetchedSeasons[tempTargetSeason] = seasonDetails;

          final episodes = seasonDetails['episodes'] as List<dynamic>? ?? [];
          final epObj = episodes.firstWhere(
            (e) => e['episode_number'] == tempTargetEpisode,
            orElse: () => <String, dynamic>{},
          );
          if (epObj.isNotEmpty &&
              epObj['name'] != null &&
              epObj['name'].toString().isNotEmpty) {
            nextTitle = epObj['name'];
          }
        } catch (_) {
          final nextToAir = details['next_episode_to_air'];
          if (nextToAir != null &&
              nextTitle == 'Episode ${nextToAir['episode_number']}') {
            if (nextToAir['season_number'].toString().padLeft(2, '0') ==
                nextCode.substring(1, 3)) {
              nextTitle = nextToAir['name'] ?? nextTitle;
            }
          }
        }

        // Count aired unwatched episodes — ONLY for seasons with unwatched eps
        for (var seasonNum in seasonsWithUnwatched) {
          try {
            // Reuse already-fetched season data
            if (!fetchedSeasons.containsKey(seasonNum)) {
              await Future.delayed(
                const Duration(milliseconds: 100),
              ); // Slight delay between season fetches
              fetchedSeasons[seasonNum] = await tmdbClient.getTvSeasonDetails(
                showId,
                seasonNum,
              );
            }
            final seasonDetails = fetchedSeasons[seasonNum]!;

            final episodes = seasonDetails['episodes'] as List<dynamic>? ?? [];

            for (var ep in episodes) {
              final epNum = (ep['episode_number'] as num?)?.toInt() ?? 0;
              if (!watchedSet.contains('$seasonNum-$epNum')) {
                final airDateStr = ep['air_date'] as String?;
                if (airDateStr != null && airDateStr.isNotEmpty) {
                  try {
                    final airDate = DateTime.parse(airDateStr);
                    final airDay = DateTime.utc(
                      airDate.year,
                      airDate.month,
                      airDate.day,
                    );
                    if (!airDay.isAfter(today)) {
                      airedUnwatchedCount++;
                    }
                  } catch (_) {}
                }
              }
            }
          } catch (_) {}
        }
      }

      if (nextTitle.startsWith('Episode ')) {
        nextTitle = '';
      }

      // Determine category and display fields
      String category;
      String episodeCode;
      String episodeTitle;
      String? extraCount;
      bool isPremiere = false;
      bool isNewEpisode = false;

      if (!foundNext || airedUnwatchedCount == 0) {
        if (watchedEpisodes.isEmpty) {
          category = 'UPCOMING_ONLY';
        } else {
          category =
              (details['status'] == 'Ended' || details['status'] == 'Canceled')
              ? 'FINISHED'
              : 'UP_TO_DATE';
        }
        episodeCode = 'Up to date';
        episodeTitle = 'Waiting for new episodes';
      } else {
        episodeCode = nextCode;
        episodeTitle = nextTitle;
        if (airedUnwatchedCount > 1) {
          extraCount = '+${airedUnwatchedCount - 1}';
        }

        if (isSeriesPremiere || isSeasonPremiere) {
          try {
            final seasonObj = seasons.firstWhere(
              (s) => s['season_number'] == tempTargetSeason,
              orElse: () => <String, dynamic>{},
            );
            if (seasonObj.isNotEmpty &&
                _isRecentlyAired(seasonObj['air_date'])) {
              isPremiere = true;
            }
          } catch (_) {}
        }

        final lastToAir = details['last_episode_to_air'];
        if (lastToAir != null) {
          final lastS = lastToAir['season_number'].toString().padLeft(2, '0');
          final lastE = lastToAir['episode_number'].toString().padLeft(2, '0');
          if (nextCode == 'S$lastS | E$lastE' &&
              _isRecentlyAired(lastToAir['air_date'])) {
            isNewEpisode = true;
          }
        }
        if (watchedEpisodes.isEmpty) {
          category = 'HAVENT_STARTED';
        } else {
          category = 'WATCH_NEXT';
        }
      }

      // --- Upcoming Logic ---
      String upcomingEpisodeCode = 'TBA';
      String upcomingEpisodeTitle = 'No upcoming episodes';
      bool upcomingIsPremiere = false;
      bool upcomingIsNew = false;
      String? upcomingAirDateStr;
      String? upcomingNetworkName;
      bool hasUpcoming = false;

      final nextToAir = details['next_episode_to_air'];
      if (nextToAir != null) {
        hasUpcoming = true;
        final sStr = nextToAir['season_number'].toString().padLeft(2, '0');
        final eStr = nextToAir['episode_number'].toString().padLeft(2, '0');
        upcomingEpisodeCode = 'S$sStr | E$eStr';

        upcomingEpisodeTitle =
            nextToAir['name'] ?? 'Episode ${nextToAir['episode_number']}';
        if (upcomingEpisodeTitle.isEmpty) {
          upcomingEpisodeTitle = 'Episode ${nextToAir['episode_number']}';
        }

        if (upcomingEpisodeTitle.startsWith('Episode ')) {
          try {
            final seasonNumInt = nextToAir['season_number'] as int;
            // Reuse already-fetched season data
            final seasonDetails =
                fetchedSeasons[seasonNumInt] ??
                await tmdbClient.getTvSeasonDetails(showId, seasonNumInt);
            fetchedSeasons[seasonNumInt] = seasonDetails;

            final episodes = seasonDetails['episodes'] as List<dynamic>? ?? [];
            final epNumInt = nextToAir['episode_number'] as int;
            final specificEp = episodes.firstWhere(
              (e) => e['episode_number'] == epNumInt,
              orElse: () => null,
            );
            if (specificEp != null &&
                specificEp['name'] != null &&
                specificEp['name'].toString().isNotEmpty) {
              upcomingEpisodeTitle = specificEp['name'];
            }
          } catch (_) {}
        }

        if (upcomingEpisodeTitle.startsWith('Episode ')) {
          upcomingEpisodeTitle = 'TBA';
        }

        bool uIsSeriesPremiere = false;
        bool uIsSeasonPremiere = false;
        final int uSeasonNumInt = nextToAir['season_number'] as int;
        final int uEpNumInt = nextToAir['episode_number'] as int;
        if (uSeasonNumInt == 1 && uEpNumInt == 1) {
          uIsSeriesPremiere = true;
        } else if (uEpNumInt == 1 && uSeasonNumInt > 1) {
          uIsSeasonPremiere = true;
        }

        upcomingAirDateStr = nextToAir['air_date'] as String?;

        if (_isUpcomingSoon(upcomingAirDateStr)) {
          if (uIsSeriesPremiere || uIsSeasonPremiere) {
            upcomingIsPremiere = true;
          } else {
            upcomingIsNew = true;
          }
        }

        final networks = details['networks'] as List<dynamic>?;
        if (networks != null && networks.isNotEmpty) {
          upcomingNetworkName = networks[0]['name'] as String?;
        }
      }

      // --- Write enrichment results back to Firestore ---
      final enrichmentData = <String, dynamic>{
        'category': category,
        'nextEpisodeCode': episodeCode,
        'nextEpisodeTitle': episodeTitle,
        'targetSeason': tempTargetSeason,
        'targetEpisode': tempTargetEpisode,
        'extraCount': extraCount,
        'isPremiere': isPremiere,
        'isNewEpisode': isNewEpisode,
        'upcomingEpisodeCode': upcomingEpisodeCode,
        'upcomingEpisodeTitle': upcomingEpisodeTitle,
        'upcomingAirDate': upcomingAirDateStr,
        'upcomingNetworkName': upcomingNetworkName,
        'hasUpcoming': hasUpcoming,
        'upcomingIsPremiere': upcomingIsPremiere,
        'upcomingIsNew': upcomingIsNew,
        'totalEpisodes': details['number_of_episodes'] ?? 0,
        'lastEnrichedAt': DateTime.now().toIso8601String(),
        if (details['origin_country'] != null)
          'origin_country': details['origin_country'],
        if (details['original_language'] != null)
          'original_language': details['original_language'],
      };

      await _repository.updateShowEnrichment(
        uid: uid,
        showId: showId,
        enrichmentData: enrichmentData,
      );

      // Mark as enriched to prevent redundant fetches
      _enrichedShowIds.add(showId);
      _watchedEpisodesHash[showId] = _computeWatchedHash(watchedEpisodes);
    } catch (e) {
      debugPrint('WatchlistEnrichmentCubit: Error enriching show $showId: $e');
    }
  }
}
