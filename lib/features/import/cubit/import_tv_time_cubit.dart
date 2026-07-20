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
  TvTimeShowData({
    required this.title,
    this.tvdbId,
    required this.watchedEpisodes,
  });
}

class TvTimeMovieData {
  String title;
  bool isWatched;
  bool inWatchlist;
  int rewatchCount;

  TvTimeMovieData({
    required this.title,
    this.isWatched = false,
    this.inWatchlist = false,
    this.rewatchCount = 0,
  });
}

class ImportTvTimeCubit extends Cubit<ImportTvTimeState> {
  final TmdbClient tmdbClient;

  ImportTvTimeCubit({required this.tmdbClient})
    : super(const ImportTvTimeState());

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
      final showsCollection = _firestore
          .collection('users')
          .doc(uid)
          .collection('shows');

      emit(
        state.copyWith(
          status: ImportTvTimeStatus.processing,
          progress: 0.05,
          statusMessage: 'Clearing existing shows...',
        ),
      );

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

      emit(
        state.copyWith(progress: 0.1, statusMessage: 'Extracting ZIP file...'),
      );

      final bytes = await state.file!.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String? followedShowsCsv;
      String? seenEpisodesCsv;
      String? trackingProdRecordsCsv;

      for (final file in archive) {
        if (file.isFile) {
          if (file.name.endsWith('followed_tv_show.csv')) {
            followedShowsCsv = utf8.decode(file.content as List<int>);
          } else if (file.name.endsWith('seen_episode.csv')) {
            seenEpisodesCsv = utf8.decode(file.content as List<int>);
          } else if (file.name.endsWith('tracking-prod-records.csv')) {
            trackingProdRecordsCsv = utf8.decode(file.content as List<int>);
          }
        }
      }

      if (followedShowsCsv == null) {
        throw Exception('followed_tv_show.csv not found in the ZIP.');
      }

      emit(
        state.copyWith(progress: 0.2, statusMessage: 'Parsing TV Time data...'),
      );

      final showsMap = <String, TvTimeShowData>{};

      // Parse followed shows
      final followedRows = Csv().decode(followedShowsCsv);
      int titleIndex = -1;
      int idIndex = -1;
      int activeIndex = -1;

      if (followedRows.isNotEmpty) {
        final header = followedRows.first
            .map((e) => e.toString().toLowerCase())
            .toList();
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
            showsMap[title.toLowerCase()] = TvTimeShowData(
              title: title,
              tvdbId: tvdbId,
              watchedEpisodes: [],
            );
          }
        }
      }

      // Parse seen episodes
      if (seenEpisodesCsv != null) {
        final seenRows = Csv().decode(seenEpisodesCsv);
        int sTitleIndex = -1, seasonIndex = -1, epIndex = -1;

        if (seenRows.isNotEmpty) {
          final header = seenRows.first
              .map((e) => e.toString().toLowerCase())
              .toList();
          sTitleIndex = header.indexOf('tv_show_name');
          seasonIndex = header.indexOf('episode_season_number');
          epIndex = header.indexOf('episode_number');
        }

        if (sTitleIndex != -1 && seasonIndex != -1 && epIndex != -1) {
          for (int i = 1; i < seenRows.length; i++) {
            final row = seenRows[i];
            if (row.length > sTitleIndex &&
                row.length > seasonIndex &&
                row.length > epIndex) {
              final title = row[sTitleIndex].toString();

              final rawSeason = row[seasonIndex].toString();
              final rawEp = row[epIndex].toString();
              final season = int.tryParse(rawSeason)?.toString() ?? rawSeason;
              final ep = int.tryParse(rawEp)?.toString() ?? rawEp;

              final titleKey = title.toLowerCase();
              if (!showsMap.containsKey(titleKey)) {
                showsMap[titleKey] = TvTimeShowData(
                  title: title,
                  watchedEpisodes: [],
                );
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

      // Parse movies
      final moviesMap = <String, TvTimeMovieData>{};
      if (trackingProdRecordsCsv != null) {
        final recordsRows = Csv().decode(trackingProdRecordsCsv);
        int mTitleIndex = -1,
            mTypeIndex = -1,
            mActionIndex = -1,
            mCountIndex = -1;

        if (recordsRows.isNotEmpty) {
          final header = recordsRows.first
              .map((e) => e.toString().toLowerCase())
              .toList();
          mTitleIndex = header.indexOf('entity_name');
          mTypeIndex = header.indexOf('entity_type');
          mActionIndex = header.indexOf('action');
          mCountIndex = header.indexOf(
            'rewatch_count',
          ); // Assume this might exist, otherwise it's just 'count' maybe? Actually the user said 'rewatch_count'
        }

        if (mTitleIndex != -1 && mTypeIndex != -1 && mActionIndex != -1) {
          for (int i = 1; i < recordsRows.length; i++) {
            final row = recordsRows[i];
            if (row.length > mTitleIndex &&
                row.length > mTypeIndex &&
                row.length > mActionIndex) {
              final type = row[mTypeIndex].toString().toLowerCase();
              if (type != 'movie') continue;

              final title = row[mTitleIndex].toString();
              final action = row[mActionIndex].toString().toLowerCase();
              final titleKey = title.toLowerCase();

              if (!moviesMap.containsKey(titleKey)) {
                moviesMap[titleKey] = TvTimeMovieData(title: title);
              }

              if (action == 'watch') {
                moviesMap[titleKey]!.isWatched = true;
              } else if (action == 'towatch') {
                moviesMap[titleKey]!.inWatchlist = true;
              }

              if (mCountIndex != -1 && row.length > mCountIndex) {
                final count = int.tryParse(row[mCountIndex].toString()) ?? 0;
                if (count > moviesMap[titleKey]!.rewatchCount) {
                  moviesMap[titleKey]!.rewatchCount = count;
                }
              }
            }
          }
        }
      }

      final moviesToImport = moviesMap.values.toList();

      if (showsToImport.isEmpty && moviesToImport.isEmpty) {
        throw Exception('No shows or movies found to import.');
      }

      WriteBatch batch = _firestore.batch();
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      final moviesCollection = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('movies');

      // Fetch existing show and movie IDs for idempotency
      final existingShowsSnapshot = await showsCollection.get();
      final existingShowIds = existingShowsSnapshot.docs
          .map((d) => int.tryParse(d.id))
          .where((id) => id != null)
          .toSet();

      final existingMoviesSnapshot = await moviesCollection.get();
      final existingMovieIds = existingMoviesSnapshot.docs
          .map((d) => int.tryParse(d.id))
          .where((id) => id != null)
          .toSet();

      int processedShowsCount = 0;
      int showsSkipped = 0;
      int showsFailed = 0;
      final totalShows = showsToImport.length;

      for (int i = 0; i < showsToImport.length; i++) {
        if (isClosed) break;
        final show = showsToImport[i];

        emit(
          state.copyWith(
            progress: 0.2 + (0.4 * (i / (totalShows > 0 ? totalShows : 1))),
            statusMessage: 'Fetching details for show: ${show.title}...',
          ),
        );

        try {
          Map<String, dynamic>? bestMatch;

          if (show.tvdbId != null && show.tvdbId!.isNotEmpty) {
            bestMatch = await tmdbClient.findByTvdbId(show.tvdbId!);
          }

          if (bestMatch == null) {
            String searchTitle = show.title;
            String? expectedYear;

            final yearMatch = RegExp(
              r'(.*)\s+\((\d{4})\)$',
            ).firstMatch(show.title);
            if (yearMatch != null) {
              searchTitle = yearMatch.group(1)!.trim();
              expectedYear = yearMatch.group(2);
            }

            final tmdbResults = await tmdbClient.searchTv(searchTitle);
            if (tmdbResults.isNotEmpty) {
              final exactMatches = tmdbResults.where((r) {
                final name = (r['name'] as String?)?.toLowerCase() ?? '';
                final originalName =
                    (r['original_name'] as String?)?.toLowerCase() ?? '';
                final target = searchTitle.toLowerCase();
                bool nameMatches = name == target || originalName == target;
                if (expectedYear != null) {
                  final airDate = r['first_air_date'] as String? ?? '';
                  bool yearMatches = airDate.startsWith(expectedYear);
                  return nameMatches && yearMatches;
                }
                return nameMatches;
              }).toList();
              if (exactMatches.isNotEmpty) {
                bestMatch = exactMatches.first as Map<String, dynamic>?;
              }
            }
          }

          if (bestMatch != null) {
            final showId = bestMatch['id'] as int;
            
            if (existingShowIds.contains(showId)) {
               if (show.watchedEpisodes.isNotEmpty) {
                 final docRef = showsCollection.doc(showId.toString());
                 batch.update(docRef, {
                   'watchedEpisodes': FieldValue.arrayUnion(show.watchedEpisodes)
                 });
                 processedShowsCount++;
               } else {
                 showsSkipped++;
               }
               continue;
            }
            
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
              data['watchedEpisodes'] = FieldValue.arrayUnion(
                show.watchedEpisodes,
              );
            }

            batch.set(docRef, data, SetOptions(merge: true));
            processedShowsCount++;
          }
        } catch (e) {
          // Skip if TMDb fails
        }

        if (processedShowsCount > 0 && processedShowsCount % 100 == 0) {
          emit(state.copyWith(statusMessage: 'Saving shows to database...'));
          await batch.commit();
          batch = _firestore.batch();
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }

      int processedMoviesCount = 0;
      int moviesSkipped = 0;
      int moviesFailed = 0;
      final totalMovies = moviesToImport.length;

      for (int i = 0; i < moviesToImport.length; i++) {
        if (isClosed) break;
        final movie = moviesToImport[i];

        emit(
          state.copyWith(
            progress: 0.6 + (0.4 * (i / (totalMovies > 0 ? totalMovies : 1))),
            statusMessage: 'Fetching details for movie: ${movie.title}...',
          ),
        );

        try {
          Map<String, dynamic>? bestMatch;

          String searchTitle = movie.title;
          String? expectedYear;

          final yearMatch = RegExp(
            r'(.*)\s+\((\d{4})\)$',
          ).firstMatch(movie.title);
          if (yearMatch != null) {
            searchTitle = yearMatch.group(1)!.trim();
            expectedYear = yearMatch.group(2);
          }

          final tmdbResults = await tmdbClient.searchMovie(searchTitle);
          if (tmdbResults.isNotEmpty) {
            final exactMatches = tmdbResults.where((r) {
              final title = (r['title'] as String?)?.toLowerCase() ?? '';
              final originalTitle =
                  (r['original_title'] as String?)?.toLowerCase() ?? '';
              final target = searchTitle.toLowerCase();
              bool nameMatches = title == target || originalTitle == target;
              if (expectedYear != null) {
                final releaseDate = r['release_date'] as String? ?? '';
                bool yearMatches = releaseDate.startsWith(expectedYear);
                return nameMatches && yearMatches;
              }
              return nameMatches;
            }).toList();
            if (exactMatches.isNotEmpty) {
              bestMatch = exactMatches.first as Map<String, dynamic>?;
            }
          }

          if (bestMatch != null) {
            final movieId = bestMatch['id'] as int;

            if (existingMovieIds.contains(movieId)) {
              continue;
            }

            final docRef = moviesCollection.doc(movieId.toString());

            final data = <String, dynamic>{
              'id': movieId,
              'title': bestMatch['title'],
              'posterPath': bestMatch['poster_path'] ?? '',
              'backdropPath': bestMatch['backdrop_path'] ?? '',
              'releaseDate': bestMatch['release_date'] ?? '',
              'runtime': bestMatch['runtime'] ?? 0,
              'voteAverage': (bestMatch['vote_average'] ?? 0).toDouble(),
              'genres': '',
              'isWatched': movie.isWatched,
              'inWatchlist': movie.inWatchlist,
              'isFavorite': false,
              'rewatchCount': movie.rewatchCount,
              'importedFrom': 'tvtime',
              'addedAt': DateTime.now().toIso8601String(),
            };

            batch.set(docRef, data, SetOptions(merge: true));
            existingMovieIds.add(movieId); // prevent duplicates in same batch
            processedMoviesCount++;
          }
        } catch (e) {
          // Skip if TMDb fails
        }

        if (processedMoviesCount > 0 && processedMoviesCount % 100 == 0) {
          emit(state.copyWith(statusMessage: 'Saving movies to database...'));
          await batch.commit();
          batch = _firestore.batch();
        }
        await Future.delayed(const Duration(milliseconds: 150));
      }

      emit(state.copyWith(statusMessage: 'Finalizing database...'));
      await batch.commit();

      emit(
        state.copyWith(
          status: ImportTvTimeStatus.completed,
          progress: 1.0,
          statusMessage: '''Import Completed!
Shows: $totalShows total -> $processedShowsCount added, $showsSkipped skipped, $showsFailed failed
Movies: $totalMovies total -> $processedMoviesCount added, $moviesSkipped skipped, $moviesFailed failed''',
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
