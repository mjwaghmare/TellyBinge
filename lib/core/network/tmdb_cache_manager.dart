import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TmdbCacheManager {
  TmdbCacheManager._();
  
  static final TmdbCacheManager instance = TmdbCacheManager._();

  static const int _maxMemoryCacheSize = 50;

  /// In-memory cache to avoid repeated file I/O operations
  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, int> _memoryCacheTimestamps = {};

  /// Cached directory path to avoid repeated platform channel calls.
  String? _cachedDirPath;

  Future<String> get _cacheDirPath async {
    if (_cachedDirPath != null) return _cachedDirPath!;
    final directory = await getTemporaryDirectory();
    final cacheDir = Directory('${directory.path}/tmdb_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cachedDirPath = cacheDir.path;
    return _cachedDirPath!;
  }

  Future<File> _getCacheFile(String key) async {
    final path = await _cacheDirPath;
    // Clean key from invalid file characters
    final safeKey = key.replaceAll(RegExp(r'[^\w\s-]'), '_');
    return File('$path/$safeKey.json');
  }

  void _evictOldestIfNeeded() {
    if (_memoryCache.length > _maxMemoryCacheSize) {
      String? oldestKey;
      int? oldestTimestamp;
      for (final entry in _memoryCacheTimestamps.entries) {
        if (oldestTimestamp == null || entry.value < oldestTimestamp) {
          oldestTimestamp = entry.value;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) {
        _memoryCache.remove(oldestKey);
        _memoryCacheTimestamps.remove(oldestKey);
      }
    }
  }

  /// Write data to cache file and in-memory cache
  Future<void> writeCache(String key, Map<String, dynamic> data) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _memoryCache[key] = data;
    _memoryCacheTimestamps[key] = timestamp;
    _evictOldestIfNeeded();

    try {
      final file = await _getCacheFile(key);
      final cacheData = {
        'timestamp': timestamp,
        'data': data,
      };
      final encoded = await compute(jsonEncode, cacheData);
      await file.writeAsString(encoded);
    } catch (e) {
      debugPrint('Error writing TMDb cache: $e');
    }
  }

  /// Read data from cache file, returns null if missing or expired
  Future<Map<String, dynamic>?> readCache(String key, {Duration maxAge = const Duration(days: 1)}) async {
    // 1. Check in-memory cache first
    if (_memoryCache.containsKey(key) && _memoryCacheTimestamps.containsKey(key)) {
      final memAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(_memoryCacheTimestamps[key]!));
      if (memAge < maxAge) {
        return _memoryCache[key];
      } else {
        _memoryCache.remove(key);
        _memoryCacheTimestamps.remove(key);
      }
    }

    // 2. Fallback to file cache
    try {
      final file = await _getCacheFile(key);
      if (!await file.exists()) return null;

      final contents = await file.readAsString();
      final cacheData = await compute(jsonDecode, contents) as Map<String, dynamic>;
      
      final timestamp = cacheData['timestamp'] as int? ?? 0;
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

      if (age < maxAge) {
        final data = cacheData['data'] as Map<String, dynamic>;
        // Populate memory cache for future reads
        _memoryCache[key] = data;
        _memoryCacheTimestamps[key] = timestamp;
        _evictOldestIfNeeded();
        return data;
      } else {
        // Cache expired, delete in background
        file.delete().catchError((_) => file);
      }
    } catch (e) {
      try {
        final file = await _getCacheFile(key);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted corrupted or invalid TMDb cache file for key: $key');
        }
      } catch (_) {}
      debugPrint('Error reading TMDb cache for key $key: $e');
    }
    return null;
  }
}
