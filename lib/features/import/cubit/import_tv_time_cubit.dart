import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'import_tv_time_state.dart';

class TvTimeShowData {
  String title;
  String? tvdbId;
  List<String> watchedEpisodes;
  TvTimeShowData({required this.title, this.tvdbId, required this.watchedEpisodes});
}

class ImportTvTimeCubit extends Cubit<ImportTvTimeState> {
  final TmdbClient tmdbClient;

  ImportTvTimeCubit({required this.tmdbClient}) : super(const ImportTvTimeState());

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> pickZip() async {
    emit(state.copyWith(status: ImportTvTimeStatus.pickingFile));

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      emit(state.copyWith(status: ImportTvTimeStatus.initial));
      return;
    }

    emit(
      state.copyWith(
        status: ImportTvTimeStatus.fileSelected,
        file: File(result.files.single.path!),
      ),
    );
  }

  Future<void> processZipLocally() async {
    if (!state.hasFile) return;

    try {
      final uid = _auth.currentUser!.uid;
      final showsCollection = _firestore.collection('users').doc(uid).collection('shows');

      emit(state.copyWith(
        status: ImportTvTimeStatus.processing,
        progress: 0.05,
        statusMessage: 'Clearing existing shows...',
      ));

      // Clear existing shows in chunks to avoid Firestore limits
      final existingShows = await showsCollection.get();
      WriteBatch deleteBatch = _firestore.batch();
      int deleteCount = 0;
      for (var doc in existingShows.docs) {
        deleteBatch.delete(doc.reference);
        deleteCount++;
        if (deleteCount % 400 == 0) {
           await deleteBatch.commit();
           deleteBatch = _firestore.batch();
        }
      }
      if (deleteCount % 400 != 0) {
         await deleteBatch.commit();
      }

      emit(state.copyWith(
        progress: 0.1,
        statusMessage: 'Extracting ZIP file...',
      ));

      final bytes = await state.file!.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String? followedShowsCsv;
      String? seenEpisodesCsv;

      for (final file in archive) {
        if (file.isFile) {
          if (file.name.endsWith('followed_tv_show.csv')) {
            followedShowsCsv = utf8.decode(file.content as List<int>);
          } else if (file.name.endsWith('seen_episode.csv')) {
            seenEpisodesCsv = utf8.decode(file.content as List<int>);
          }
        }
      }

      if (followedShowsCsv == null) {
        throw Exception('followed_tv_show.csv not found in the ZIP.');
      }

      emit(state.copyWith(
        progress: 0.2,
        statusMessage: 'Parsing TV Time data...',
      ));

      final showsMap = <String, TvTimeShowData>{};

      // Parse followed shows
      final followedRows = Csv().decode(followedShowsCsv);
      int titleIndex = -1;
      int idIndex = -1;
      int activeIndex = -1;
      
      if (followedRows.isNotEmpty) {
        final header = followedRows.first.map((e) => e.toString().toLowerCase()).toList();
        titleIndex = header.indexOf('tv_show_name');
        idIndex = header.indexOf('tv_show_id');
        activeIndex = header.indexOf('active');
      }

      if (titleIndex != -1) {
        for (int i = 1; i < followedRows.length; i++) {
          final row = followedRows[i];
          if (row.length > titleIndex) {
             
            // Skip shows that were added and later removed/unfollowed
            if (activeIndex != -1 && row.length > activeIndex) {
              if (row[activeIndex].toString() == '0') {
                continue;
              }
            }
             
            final title = row[titleIndex].toString();
            String? tvdbId;
            if (idIndex != -1 && row.length > idIndex) {
               tvdbId = row[idIndex].toString();
            }
            showsMap[title.toLowerCase()] = TvTimeShowData(title: title, tvdbId: tvdbId, watchedEpisodes: []);
          }
        }
      }

      // Parse seen episodes
      if (seenEpisodesCsv != null) {
         final seenRows = Csv().decode(seenEpisodesCsv);
         int sTitleIndex = -1, seasonIndex = -1, epIndex = -1;
         
         if (seenRows.isNotEmpty) {
            final header = seenRows.first.map((e) => e.toString().toLowerCase()).toList();
            sTitleIndex = header.indexOf('tv_show_name');
            seasonIndex = header.indexOf('episode_season_number');
            epIndex = header.indexOf('episode_number');
         }

          if (sTitleIndex != -1 && seasonIndex != -1 && epIndex != -1) {
            for (int i = 1; i < seenRows.length; i++) {
              final row = seenRows[i];
              if (row.length > sTitleIndex && row.length > seasonIndex && row.length > epIndex) {
                final title = row[sTitleIndex].toString();
                
                final rawSeason = row[seasonIndex].toString();
                final rawEp = row[epIndex].toString();
                final season = int.tryParse(rawSeason)?.toString() ?? rawSeason;
                final ep = int.tryParse(rawEp)?.toString() ?? rawEp;
                
                final titleKey = title.toLowerCase();
                if (!showsMap.containsKey(titleKey)) {
                  showsMap[titleKey] = TvTimeShowData(title: title, watchedEpisodes: []);
                }
                
                final epKey = '$season-$ep';
                if (!showsMap[titleKey]!.watchedEpisodes.contains(epKey)) {
                   showsMap[titleKey]!.watchedEpisodes.add(epKey);
                }
              }
            }
         }
      }

      final showsToImport = showsMap.values.toList();
      
      if (showsToImport.isEmpty) {
        throw Exception('No shows found to import.');
      }

      WriteBatch batch = _firestore.batch();

      int processedCount = 0;
      final total = showsToImport.length;

      for (int i = 0; i < showsToImport.length; i++) {
        if (isClosed) break;
        final show = showsToImport[i];
        
        emit(state.copyWith(
          progress: 0.2 + (0.8 * (i / total)),
          statusMessage: 'Fetching details for ${show.title}...',
        ));

        try {
          Map<String, dynamic>? bestMatch;
          
          if (show.tvdbId != null && show.tvdbId!.isNotEmpty) {
             bestMatch = await tmdbClient.findByTvdbId(show.tvdbId!);
          }
          
          if (bestMatch == null) {
            String searchTitle = show.title;
            String? expectedYear;
            
            // TV Time sometimes exports titles like "Doctor Who (2005)"
            final yearMatch = RegExp(r'(.*)\s+\((\d{4})\)$').firstMatch(show.title);
            if (yearMatch != null) {
              searchTitle = yearMatch.group(1)!.trim();
              expectedYear = yearMatch.group(2);
            }

            final tmdbResults = await tmdbClient.searchTv(searchTitle);
            if (tmdbResults.isNotEmpty) {
               final exactMatches = tmdbResults.where(
                  (r) {
                    final name = (r['name'] as String?)?.toLowerCase() ?? '';
                    final originalName = (r['original_name'] as String?)?.toLowerCase() ?? '';
                    final target = searchTitle.toLowerCase();
                    
                    bool nameMatches = name == target || originalName == target;
                    
                    if (expectedYear != null) {
                      final airDate = r['first_air_date'] as String? ?? '';
                      bool yearMatches = airDate.startsWith(expectedYear);
                      return nameMatches && yearMatches;
                    }
                    
                    return nameMatches;
                  }
               ).toList();
               
               if (exactMatches.isNotEmpty) {
                 bestMatch = exactMatches.first as Map<String, dynamic>?;
               }
            }
          }
          
          if (bestMatch != null) {
             final showId = bestMatch['id'];
             final docRef = showsCollection.doc(showId.toString());
             
             final data = <String, dynamic>{
                'id': showId,
                'name': bestMatch['name'],
                'posterPath': bestMatch['poster_path'] ?? '',
                'backdropPath': bestMatch['backdrop_path'] ?? '',
                'firstAirDate': bestMatch['first_air_date'] ?? '',
                'voteAverage': (bestMatch['vote_average'] ?? 0).toDouble(),
                'addedAt': DateTime.now().toIso8601String(),
             };
             
             if (show.watchedEpisodes.isNotEmpty) {
                 data['watchedEpisodes'] = FieldValue.arrayUnion(show.watchedEpisodes);
             }
             
             batch.set(docRef, data, SetOptions(merge: true));
             processedCount++;
          }
        } catch (e) {
           // Skip if TMDb fails
        }
        
        // Commit batches of 100
        if (processedCount > 0 && processedCount % 100 == 0) {
            emit(state.copyWith(statusMessage: 'Saving to database...'));
            await batch.commit();
            batch = _firestore.batch(); // Create a new batch
        }

        // Throttle requests (150ms delay) to prevent TMDb API rate limits
        await Future.delayed(const Duration(milliseconds: 150));
      }
      
      // Commit remaining
      if (processedCount % 100 != 0) {
          emit(state.copyWith(statusMessage: 'Saving to database...'));
          await batch.commit();
      }

      emit(
        state.copyWith(
          status: ImportTvTimeStatus.completed, 
          progress: 1.0,
          statusMessage: 'Import completed successfully!',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ImportTvTimeStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void reset() {
    emit(const ImportTvTimeState());
  }
}
