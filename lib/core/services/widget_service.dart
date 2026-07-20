import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/dashboard/data/repositories/tv_watchlist_repository_impl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/dashboard/presentation/cubit/watchlist_enrichment_cubit.dart';
import '../../core/network/tmdb_client.dart';
class WidgetService {
  static const String iOSGroupId = 'group.tvtimeapp.widget';
  static const String androidWidgetName = 'UpNextWidgetProvider';

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

  static Future<void> updateUpNextWidget(List<Map<String, dynamic>> items) async {
    _debounceTimer?.cancel();
    
    // Copy the items list to prevent modifications while waiting for the timer
    final itemsCopy = List<Map<String, dynamic>>.from(
      items.map((item) => Map<String, dynamic>.from(item))
    );

    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        if (itemsCopy.isEmpty) {
          // Pass empty JSON
          await HomeWidget.saveWidgetData<String>('up_next_items', '[]');
        } else {
          // Download images and attach local paths
          for (var i = 0; i < itemsCopy.length; i++) {
            final posterPath = itemsCopy[i]['posterPath'] as String?;
            if (posterPath != null && posterPath.isNotEmpty) {
              String fullPosterUrl;
              if (posterPath.startsWith('http')) {
                fullPosterUrl = posterPath;
              } else {
                final cleanPath = posterPath.startsWith('/') ? posterPath : '/$posterPath';
                fullPosterUrl = 'https://image.tmdb.org/t/p/w500$cleanPath';
              }
              itemsCopy[i]['localPosterPath'] = fullPosterUrl; // We'll map this in Swift
            }
          }
          
          final jsonData = jsonEncode(itemsCopy);
          await HomeWidget.saveWidgetData<String>('up_next_items', jsonData);
        }

        // Trigger native update
        await HomeWidget.updateWidget(
          name: androidWidgetName,
          iOSName: 'UpNextWidget',
        );
      } catch (e) {
        log('Error updating Up Next Widget: $e');
      }
    });
  }

  static Future<void> syncWatchlistToWidget(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shows')
        .orderBy('addedAt', descending: true)
        .get();
        
    final shows = snapshot.docs.map((doc) => doc.data()).toList();
    
    // Priority 1: Watch Next
    final watchNext = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        show['category'] != 'UP_TO_DATE' &&
        show['category'] != 'HAVENT_STARTED' &&
        show['nextEpisodeCode'] != null &&
        show['nextEpisodeCode'].toString().isNotEmpty &&
        !show['nextEpisodeCode'].toString().startsWith('Up to date')
    ).toList();

    // Priority 2: Haven't Started
    final haventStarted = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        show['category'] == 'HAVENT_STARTED'
    ).toList();

    // Priority 3: Upcoming
    final upcoming = shows.where((show) =>
        show['status'] != 'STOPPED' &&
        (show['category'] == 'UP_TO_DATE' || show['hasUpcoming'] == true) &&
        show['upcomingEpisodeCode'] != null &&
        show['upcomingEpisodeCode'] != 'TBA'
    ).toList();

    final List<Map<String, dynamic>> widgetItems = [];

    // Fill from Watch Next first
    for (var show in watchNext) {
      if (widgetItems.length >= 3) break;
      final int targetSeason = (show['targetSeason'] as num?)?.toInt() ?? 0;
      final int targetEpisode = (show['targetEpisode'] as num?)?.toInt() ?? 0;
      final String firestoreKey = '$targetSeason-$targetEpisode';
      widgetItems.add({
        'showId': show['id'] as int,
        'showName': show['name'] as String,
        'header': show['isPremiere'] == true ? 'PREMIERE' : (show['isNewEpisode'] == true ? 'NEW EPISODE' : 'UP NEXT'),
        'episodeTitle': show['nextEpisodeCode'] as String,
        'episodeDetails': show['nextEpisodeTitle'] as String,
        'posterPath': show['posterPath'] as String?,
        'episodeKey': firestoreKey,
      });
    }

    // Backfill remaining slots from Haven't Started
    for (var show in haventStarted) {
      if (widgetItems.length >= 3) break;
      final episodeTitle = (show['nextEpisodeCode'] != null && show['nextEpisodeCode'].toString().isNotEmpty)
          ? show['nextEpisodeCode'] as String
          : 'S01 | E01';
      final episodeDetails = (show['nextEpisodeTitle'] != null && show['nextEpisodeTitle'].toString().isNotEmpty)
          ? show['nextEpisodeTitle'] as String
          : 'Pilot';
      widgetItems.add({
        'showId': show['id'] as int,
        'showName': show['name'] as String,
        'header': 'START WATCHING',
        'episodeTitle': episodeTitle,
        'episodeDetails': episodeDetails,
        'posterPath': show['posterPath'] as String?,
        'episodeKey': '1-1',
      });
    }

    // If both Watch Next and Haven't Started are empty, fall back to Upcoming
    if (widgetItems.isEmpty) {
      for (var show in upcoming) {
        if (widgetItems.length >= 3) break;
        
        String upcomingDetail = show['upcomingEpisodeTitle'] ?? '';
        if (show['upcomingAirDate'] != null) {
            final airDate = DateTime.tryParse(show['upcomingAirDate']);
            if (airDate != null) {
                final days = airDate.difference(DateTime.now()).inDays;
                if (days > 0) {
                    upcomingDetail = 'In $days days • $upcomingDetail';
                } else if (days == 0) {
                    upcomingDetail = 'Today • $upcomingDetail';
                }
            }
        }

        widgetItems.add({
          'showId': show['id'] as int,
          'showName': show['name'] as String,
          'header': show['upcomingIsPremiere'] == true ? 'NEXT SEASON' : 'UPCOMING',
          'episodeTitle': show['upcomingEpisodeCode'] as String,
          'episodeDetails': upcomingDetail,
          'posterPath': show['posterPath'] as String?,
          'episodeKey': '',
        });
      }
    }

    await updateUpNextWidget(widgetItems);
  }
}

// Global function for HomeWidget background callback (e.g. Interactive Intent)
@pragma('vm:entry-point')
Future<void> interactiveWidgetCallback(Uri? uri) async {
  if (uri == null) return;
  
  // Format: tvtimeapp://mark_watched?showId=123&episodeKey=S1E1
  if (uri.scheme == 'tvtimeapp' && uri.host == 'mark_watched') {
    final showIdStr = uri.queryParameters['showId'];
    final episodeKey = uri.queryParameters['episodeKey'];
    
    if (showIdStr != null && episodeKey != null) {
      final showId = int.tryParse(showIdStr);
      if (showId != null) {
        // Initialize Firebase since this is a background isolate
        try {
          await Firebase.initializeApp();
          await dotenv.load(fileName: '.env');
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            final repo = TvWatchlistRepositoryImpl();
            await repo.toggleEpisodeWatched(
              uid: uid,
              showId: showId,
              episodeKey: episodeKey,
              isWatched: true,
            );
            log('Background: Marked episode $episodeKey as watched for show $showId');
            
            // Enrich the show
            final showDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('shows')
                .doc(showId.toString())
                .get();

            if (showDoc.exists) {
              final tmdbClient = TmdbClient();
              final enrichmentCubit = WatchlistEnrichmentCubit(tmdbClient: tmdbClient);
              await enrichmentCubit.enrichShows([showDoc.data()!], uid);
              enrichmentCubit.close();
            }

            // Sync watchlist to widget
            await WidgetService.syncWatchlistToWidget(uid);
          }
        } catch (e) {
          log('Error in background interactive widget callback: $e');
        }
      }
    }
  }
}

