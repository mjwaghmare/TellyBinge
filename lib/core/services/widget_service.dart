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

  static final _upNextWriter = WidgetDebouncedWriter();
  static final _statsWriter = WidgetDebouncedWriter();

  /// Runs any queued widget write immediately instead of waiting out the
  /// debounce. Called when the app leaves the foreground: iOS suspends the
  /// isolate on background, so a pending Timer would otherwise never fire and
  /// the widget would sit stale until the next resume.
  static Future<void> flushPendingUpdate() async {
    await Future.wait([_upNextWriter.flush(), _statsWriter.flush()]);
  }

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
                final cleanPath = posterPath.startsWith('/')
                    ? posterPath
                    : '/$posterPath';
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

    await _upNextWriter.schedule(write, immediate: immediate);
  }

  /// [immediate] skips the debounce and writes synchronously.
  static Future<void> updateProfileStatsWidget({
    required String userName,
    required int showsCount,
    required int episodesCount,
    required String showsFormattedTime,
    required int moviesCount,
    required String moviesFormattedTime,
    bool immediate = false,
  }) async {
    Future<void> write() async {
      try {
        await HomeWidget.saveWidgetData<String>('stats_user_name', userName);
        await HomeWidget.saveWidgetData<int>('stats_shows_count', showsCount);
        await HomeWidget.saveWidgetData<int>(
          'stats_episodes_count',
          episodesCount,
        );
        await HomeWidget.saveWidgetData<String>(
          'stats_shows_time',
          showsFormattedTime,
        );
        await HomeWidget.saveWidgetData<int>('stats_movies_count', moviesCount);
        await HomeWidget.saveWidgetData<String>(
          'stats_movies_time',
          moviesFormattedTime,
        );

        await HomeWidget.updateWidget(
          name: androidWidgetName,
          iOSName: 'UpNextWidget',
        );
      } catch (e) {
        log('Error updating Profile Stats Widget: $e');
      }
    }

    await _statsWriter.schedule(write, immediate: immediate);
  }

  static Future<void> syncWatchlistToWidget(
    String uid, {
    bool immediate = false,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('current_uid', uid);
    } catch (e) {
      log('Error saving current_uid: $e');
    }
    final repo = TvWatchlistRepositoryImpl();
    final shows = await repo.getShows(uid: uid).timeout(_backgroundOpTimeout);
    await syncWatchlistDataToWidget(
      shows.map((s) => s.toMap()).toList(),
      immediate: immediate,
    );
  }

  static Future<void> syncWatchlistDataToWidget(
    List<Map<String, dynamic>> shows, {
    bool immediate = false,
  }) async {
    final enrichedShows = shows
        .map((data) => EnrichedShow.fromShowData(data))
        .toList();

    final watchNext = <EnrichedShow>[];
    final haventStarted = <EnrichedShow>[];
    final upcoming = <EnrichedShow>[];

    for (var show in enrichedShows) {
      if ((show.rawShowData['status'] as String?) == 'STOPPED') continue;

      if (show.hasUpcoming && show.upcomingAirDate != null) {
        upcoming.add(show);
      }

      if (show.watchlistStatus == 'UPCOMING_ONLY') continue;
      if (show.watchlistStatus == 'UP_TO_DATE' ||
          show.watchlistStatus == 'FINISHED') {
        continue;
      }

      if (show.watchlistStatus == 'HAVENT_STARTED') {
        haventStarted.add(show);
      } else {
        watchNext.add(show);
      }
    }

    DateTime? getReleaseDate(EnrichedShow show) {
      final dateStr =
          (show.rawShowData['firstAirDate'] ??
                  show.rawShowData['first_air_date'] ??
                  show.rawShowData['releaseDate'] ??
                  show.rawShowData['release_date'])
              as String?;
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
        'header': show.isPremiere
            ? 'PREMIERE'
            : (show.isNew ? 'NEW EPISODE' : 'WATCH NEXT'),
        'episodeTitle': show.episodeCode,
        'episodeDetails': show.episodeTitle.isNotEmpty
            ? show.episodeTitle
            : 'Episode $targetEpisode',
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
        'episodeDetails': show.episodeTitle.isNotEmpty
            ? show.episodeTitle
            : 'Episode 1',
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
          'showName':
              (show.rawShowData['name'] as String?) ?? 'Unknown TV Show',
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
  final msg =
      '🚀 [Background Isolate] Interactive widget callback received with URI: $uri';
  log(msg);
  debugPrint(msg);
  WidgetsFlutterBinding.ensureInitialized();

  if (uri == null) return;

  if (uri.scheme != 'tvtimeapp' || uri.host != 'mark_watched') return;

  final showIdStr = uri.queryParameters['showId'];
  final episodeKey = uri.queryParameters['episodeKey'];

  if (showIdStr == null || episodeKey == null) {
    debugPrint('Background callback: missing showId or episodeKey in $uri');
    return;
  }

  final cleanShowIdStr = showIdStr.replaceAll(',', '').replaceAll(' ', '');
  final showId = int.tryParse(cleanShowIdStr);
  if (showId == null) {
    debugPrint('Background callback: invalid showId "$showIdStr"');
    return;
  }

  debugPrint(
    '📌 [Background Isolate] Processing mark-as-watched for showId: $showId, episodeKey: $episodeKey',
  );

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
        await dotenv
            .load(fileName: '.env')
            .timeout(WidgetService._backgroundOpTimeout);
        dotenvAvailable = true;
      } catch (e) {
        debugPrint(
          'Background callback: dotenv unavailable in headless isolate, skipping TMDB enrichment: $e',
        );
      }
    }

    var user = FirebaseAuth.instance.currentUser;
    String? uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      try {
        final u = await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 2),
        );
        uid = u?.uid;
      } catch (_) {}
    }
    if (uid == null || uid.isEmpty) {
      uid = await HomeWidget.getWidgetData<String>('current_uid');
    }

    if (uid == null || uid.isEmpty) {
      debugPrint(
        'Background callback: no authenticated user, aborting mark-as-watched for show $showId',
      );
      return;
    }

    final repo = TvWatchlistRepositoryImpl();
    final showItem = await repo
        .getShow(uid: uid, showId: showId)
        .timeout(WidgetService._backgroundOpTimeout);

    String? showName;
    String? showPoster;
    String? episodeTitle;

    if (showItem != null) {
      showName = showItem.name;
      showPoster = showItem.posterPath;
      final enriched = EnrichedShow.fromShowData(showItem.toMap());
      episodeTitle = enriched.episodeTitle.isNotEmpty
          ? enriched.episodeTitle
          : enriched.episodeCode;
    }

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

    debugPrint(
      'Background: Marked episode $episodeKey as watched for show $showId ($showName)',
    );

    if (showItem != null) {
      final showMap = showItem.toMap();
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

      final allShows = await repo
          .getShows(uid: uid)
          .timeout(WidgetService._backgroundOpTimeout);

      final updatedShows = allShows.map((doc) {
        if (doc.id.toString() == showId.toString()) {
          return showMap;
        }
        return doc.toMap();
      }).toList();

      // Immediate widget sync with optimistic data
      await WidgetService.syncWatchlistDataToWidget(
        updatedShows,
        immediate: true,
      );

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
          debugPrint('Background callback: TMDB enrichment failed: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('Error in background interactive widget callback: $e');
  } finally {
    enrichmentCubit?.close();
  }
}

class WidgetDebouncedWriter {
  final Duration debounceWindow;
  final Duration maxDebounceWait;

  Timer? _timer;
  Future<void> Function()? _pendingWrite;
  DateTime? _pendingSince;

  WidgetDebouncedWriter({
    this.debounceWindow = const Duration(milliseconds: 800),
    this.maxDebounceWait = const Duration(seconds: 3),
  });

  Future<void> schedule(
    Future<void> Function() write, {
    bool immediate = false,
  }) async {
    if (immediate) {
      _cancelAndReset();
      await write();
      return;
    }

    _timer?.cancel();
    _pendingWrite = write;
    final since = _pendingSince ??= DateTime.now();

    if (DateTime.now().difference(since) >= maxDebounceWait) {
      _resetState();
      await write();
      return;
    }

    _timer = Timer(debounceWindow, () {
      _resetState();
      write();
    });
  }

  Future<void> flush() async {
    final pending = _pendingWrite;
    if (pending == null) return;
    _cancelAndReset();
    await pending();
  }

  void _cancelAndReset() {
    _timer?.cancel();
    _resetState();
  }

  void _resetState() {
    _timer = null;
    _pendingWrite = null;
    _pendingSince = null;
  }
}
