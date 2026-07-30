import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/dashboard/data/repositories/tv_watchlist_repository_impl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/dashboard/presentation/cubit/watchlist_enrichment_cubit.dart';
import '../../core/network/tmdb_client.dart';
import '../../features/dashboard/presentation/models/enriched_show.dart';

class WidgetService {
  static const String iOSGroupId = 'group.tvtimeapp.widget';
  static const String androidWidgetName = 'UpNextWidgetProvider';

  // Background-isolate operations get a hard budget. Tune based on observed
  // iOS background execution allowance for widget intents.
  static const Duration _backgroundOpTimeout = Duration(seconds: 15);

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(iOSGroupId);
      await HomeWidget.registerInteractivityCallback(interactiveWidgetCallback);
      log('WidgetService initialized');
    } catch (e) {
      log('Error initializing WidgetService: $e');
    }
  }

  static Timer? _debounceTimer;

  /// [immediate] skips the debounce and writes synchronously. Required for
  /// background-isolate callers (e.g. mark-as-watched from the widget) since
  /// the headless engine is torn down once the triggering call completes —
  /// a debounced Timer scheduled for later has nothing left to run on.
  static Future<void> updateUpNextWidget(
    List<Map<String, dynamic>> items, {
    bool immediate = false,
  }) async {
    final itemsCopy = List<Map<String, dynamic>>.from(
      items.map((item) => Map<String, dynamic>.from(item)),
    );

    Future<void> write() async {
      try {
        if (itemsCopy.isEmpty) {
          await HomeWidget.saveWidgetData<String>('up_next_items', '[]');
        } else {
          for (var i = 0; i < itemsCopy.length; i++) {
            final posterPath = itemsCopy[i]['posterPath'] as String?;
            if (posterPath != null && posterPath.isNotEmpty) {
              String fullPosterUrl;
              if (posterPath.startsWith('http')) {
                fullPosterUrl = posterPath;
              } else {
                final cleanPath =
                    posterPath.startsWith('/') ? posterPath : '/$posterPath';
                fullPosterUrl = 'https://image.tmdb.org/t/p/w500$cleanPath';
              }
              itemsCopy[i]['localPosterPath'] = fullPosterUrl;
            }
          }

          final jsonData = jsonEncode(itemsCopy);
          await HomeWidget.saveWidgetData<String>('up_next_items', jsonData);
        }

        await HomeWidget.updateWidget(
          name: androidWidgetName,
          iOSName: 'UpNextWidget',
        );
      } catch (e) {
        log('Error updating Up Next Widget: $e');
      }
    }

    if (immediate) {
      _debounceTimer?.cancel();
      await write();
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), write);
  }

  static Future<void> syncWatchlistToWidget(
    String uid, {
    bool immediate = false,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shows')
        .orderBy('addedAt', descending: true)
        .get()
        .timeout(_backgroundOpTimeout);

    final shows = snapshot.docs.map((doc) => doc.data()).toList();
    await syncWatchlistDataToWidget(shows, immediate: immediate);
  }

  static Future<void> syncWatchlistDataToWidget(
    List<Map<String, dynamic>> shows, {
    bool immediate = false,
  }) async {
    final enrichedShows = shows.map((data) => EnrichedShow.fromShowData(data)).toList();

    final watchNext = <EnrichedShow>[];
    final haventStarted = <EnrichedShow>[];
    final upcoming = <EnrichedShow>[];

    for (var show in enrichedShows) {
      if ((show.rawShowData['status'] as String?) == 'STOPPED') continue;

      if (show.hasUpcoming && show.upcomingAirDate != null) {
        upcoming.add(show);
      }

      if (show.watchlistStatus == 'UPCOMING_ONLY') continue;
      if (show.watchlistStatus == 'UP_TO_DATE' || show.watchlistStatus == 'FINISHED') {
        continue;
      }

      if (show.watchlistStatus == 'HAVENT_STARTED') {
        haventStarted.add(show);
      } else {
        watchNext.add(show);
      }
    }

    DateTime? getReleaseDate(EnrichedShow show) {
      final dateStr = (show.rawShowData['firstAirDate'] ??
              show.rawShowData['first_air_date'] ??
              show.rawShowData['releaseDate'] ??
              show.rawShowData['release_date']) as String?;
      if (dateStr == null || dateStr.isEmpty) return null;
      return DateTime.tryParse(dateStr);
    }

    watchNext.sort((a, b) {
      final aDate = getReleaseDate(a);
      final bDate = getReleaseDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    haventStarted.sort((a, b) {
      final aDate = getReleaseDate(a);
      final bDate = getReleaseDate(b);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    upcoming.sort((a, b) => a.upcomingAirDate!.compareTo(b.upcomingAirDate!));

    final List<Map<String, dynamic>> widgetItems = [];

    for (var show in watchNext) {
      if (widgetItems.length >= 4) break;
      final int targetSeason = show.targetSeason;
      final int targetEpisode = show.targetEpisode;
      final String firestoreKey = '$targetSeason-$targetEpisode';
      widgetItems.add({
        'showId': (show.rawShowData['id'] as num?)?.toInt() ?? 0,
        'showName': (show.rawShowData['name'] as String?) ?? 'Unknown TV Show',
        'header': show.isPremiere ? 'PREMIERE' : (show.isNew ? 'NEW EPISODE' : 'WATCH NEXT'),
        'episodeTitle': show.episodeCode,
        'episodeDetails': show.episodeTitle,
        'posterPath': show.rawShowData['posterPath'] as String?,
        'episodeKey': firestoreKey,
      });
    }

    for (var show in haventStarted) {
      if (widgetItems.length >= 4) break;
      widgetItems.add({
        'showId': (show.rawShowData['id'] as num?)?.toInt() ?? 0,
        'showName': (show.rawShowData['name'] as String?) ?? 'Unknown TV Show',
        'header': 'START WATCHING',
        'episodeTitle': show.episodeCode,
        'episodeDetails': show.episodeTitle,
        'posterPath': show.rawShowData['posterPath'] as String?,
        'episodeKey': '1-1',
      });
    }

    if (widgetItems.isEmpty) {
      for (var show in upcoming) {
        if (widgetItems.length >= 4) break;

        String upcomingDetail = show.upcomingEpisodeTitle;
        if (show.upcomingAirDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final targetDate = DateTime(
            show.upcomingAirDate!.year,
            show.upcomingAirDate!.month,
            show.upcomingAirDate!.day,
          );
          final days = targetDate.difference(today).inDays;

          if (days > 0) {
            upcomingDetail = 'In $days days • $upcomingDetail';
          } else if (days == 0) {
            upcomingDetail = 'Today • $upcomingDetail';
          }
        }

        widgetItems.add({
          'showId': (show.rawShowData['id'] as num?)?.toInt() ?? 0,
          'showName': (show.rawShowData['name'] as String?) ?? 'Unknown TV Show',
          'header': show.upcomingIsPremiere ? 'NEXT SEASON' : 'UPCOMING',
          'episodeTitle': show.upcomingEpisodeCode,
          'episodeDetails': upcomingDetail,
          'posterPath': show.rawShowData['posterPath'] as String?,
          'episodeKey': '',
        });
      }
    }

    await updateUpNextWidget(widgetItems, immediate: immediate);
  }
}

@pragma('vm:entry-point')
Future<void> interactiveWidgetCallback(Uri? uri) async {
  log('🚀 [Background Isolate] Interactive widget callback received with URI: $uri');
  WidgetsFlutterBinding.ensureInitialized();

  if (uri == null) return;

  if (uri.scheme != 'tvtimeapp' || uri.host != 'mark_watched') return;

  final showIdStr = uri.queryParameters['showId'];
  final episodeKey = uri.queryParameters['episodeKey'];

  if (showIdStr == null || episodeKey == null) {
    log('Background callback: missing showId or episodeKey in $uri');
    return;
  }

  final cleanShowIdStr = showIdStr.replaceAll(',', '').replaceAll(' ', '');
  final showId = int.tryParse(cleanShowIdStr);
  if (showId == null) {
    log('Background callback: invalid showId "$showIdStr"');
    return;
  }

  log('📌 [Background Isolate] Processing mark-as-watched for showId: $showId, episodeKey: $episodeKey');

  WatchlistEnrichmentCubit? enrichmentCubit;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(WidgetService._backgroundOpTimeout);
    }

    bool dotenvAvailable = dotenv.isInitialized;
    if (!dotenvAvailable) {
      try {
        await dotenv.load(fileName: '.env').timeout(WidgetService._backgroundOpTimeout);
        dotenvAvailable = true;
      } catch (e) {
        log('Background callback: dotenv unavailable in headless isolate, skipping TMDB enrichment: $e');
      }
    }

    var user = FirebaseAuth.instance.currentUser;
    String? uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      try {
        final u = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 2));
        uid = u?.uid;
      } catch (_) {}
    }
    if (uid == null || uid.isEmpty) {
      uid = await HomeWidget.getWidgetData<String>('current_uid');
    }

    if (uid == null || uid.isEmpty) {
      log('Background callback: no authenticated user, aborting mark-as-watched for show $showId');
      return;
    }

    final showDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .get()
        .timeout(WidgetService._backgroundOpTimeout);

    String? showName;
    String? showPoster;
    String? episodeTitle;

    if (showDoc.exists) {
      final showData = showDoc.data()!;
      showName = showData['name'] as String?;
      showPoster = showData['posterPath'] as String?;
      final enriched = EnrichedShow.fromShowData(showData);
      episodeTitle = enriched.episodeTitle.isNotEmpty
          ? enriched.episodeTitle
          : enriched.episodeCode;
    }

    final repo = TvWatchlistRepositoryImpl();
    await repo
        .toggleEpisodeWatched(
          uid: uid,
          showId: showId,
          episodeKey: episodeKey,
          isWatched: true,
          showName: showName,
          showPoster: showPoster,
          episodeTitle: episodeTitle,
        )
        .timeout(WidgetService._backgroundOpTimeout);

    log('Background: Marked episode $episodeKey as watched for show $showId ($showName)');

    if (showDoc.exists) {
      final showMap = Map<String, dynamic>.from(showDoc.data()!);
      final watchedList = List<String>.from(showMap['watchedEpisodes'] ?? []);
      if (!watchedList.contains(episodeKey)) {
        watchedList.add(episodeKey);
        showMap['watchedEpisodes'] = watchedList;
      }

      // Optimistically advance targetEpisode for instant widget update
      int tSeason = (showMap['targetSeason'] as num?)?.toInt() ?? 1;
      int tEpisode = (showMap['targetEpisode'] as num?)?.toInt() ?? 1;
      while (watchedList.contains('$tSeason-$tEpisode')) {
        tEpisode++;
      }
      showMap['targetSeason'] = tSeason;
      showMap['targetEpisode'] = tEpisode;
      showMap['nextEpisodeCode'] =
          'S${tSeason.toString().padLeft(2, '0')} | E${tEpisode.toString().padLeft(2, '0')}';
      showMap['nextEpisodeTitle'] = 'Episode $tEpisode';

      final allShowsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('shows')
          .orderBy('addedAt', descending: true)
          .get()
          .timeout(WidgetService._backgroundOpTimeout);

      final allShows = allShowsSnapshot.docs.map((doc) {
        if (doc.id == showId.toString()) {
          return showMap;
        }
        return doc.data();
      }).toList();

      // Immediate widget sync with optimistic data
      await WidgetService.syncWatchlistDataToWidget(allShows, immediate: true);

      // Async TMDB enrichment — only if dotenv loaded (API key available)
      if (dotenvAvailable) {
        try {
          final tmdbClient = TmdbClient();
          enrichmentCubit = WatchlistEnrichmentCubit(tmdbClient: tmdbClient);
          await enrichmentCubit
              .enrichShows([showMap], uid, force: true)
              .timeout(WidgetService._backgroundOpTimeout);
          await WidgetService.syncWatchlistToWidget(uid, immediate: true);
        } catch (e) {
          log('Background callback: TMDB enrichment failed: $e');
        }
      }
    }
  } catch (e) {
    log('Error in background interactive widget callback: $e');
  } finally {
    enrichmentCubit?.close();
  }
}
