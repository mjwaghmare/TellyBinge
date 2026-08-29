import 'package:flutter/foundation.dart';

enum AppUpdateType {
  none,
  optional,
  force,
}

@immutable
class AppVersionInfo {
  final String latestVersion;
  final bool isOptional;
  final String title;
  final List<String> releaseNotes;
  final String androidUrl;
  final String iosUrl;
  final bool isUpdateEnabled;

  const AppVersionInfo({
    required this.latestVersion,
    this.isOptional = true,
    this.title = 'Update Available!',
    this.releaseNotes = const [],
    this.androidUrl = '',
    this.iosUrl = '',
    this.isUpdateEnabled = true,
  });

  factory AppVersionInfo.fromMap(Map<String, dynamic> map) {
    List<String> parseNotes(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (raw is String && raw.trim().isNotEmpty) {
        return raw
            .split('\n')
            .map((e) => e.trim().replaceFirst(RegExp(r'^[-*•]\s*'), ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final newVersion = (map['version'] ??
            map['new_version'] ??
            map['latest_version'] ??
            map['latestVersion'] ??
            '1.0.0')
        .toString()
        .trim();

    // Check is_optional flag directly
    bool isOpt = true;
    if (map.containsKey('is_optional') ||
        map.containsKey('is_optional_update') ||
        map.containsKey('isOptional')) {
      isOpt = map['is_optional'] as bool? ??
          map['is_optional_update'] as bool? ??
          map['isOptional'] as bool? ??
          true;
    } else if (map.containsKey('is_force') || map.containsKey('is_force_update')) {
      final isForce = map['is_force'] as bool? ?? map['is_force_update'] as bool? ?? false;
      isOpt = !isForce;
    } else if (map.containsKey('min_supported_version')) {
      // Legacy fallback
      final minVersion = map['min_supported_version'].toString().trim();
      isOpt = compareVersions(newVersion, minVersion) > 0;
    }

    return AppVersionInfo(
      latestVersion: newVersion,
      isOptional: isOpt,
      title: (map['title'] ?? 'Update Available!').toString().trim(),
      releaseNotes: parseNotes(map['release_notes'] ?? map['releaseNotes'] ?? map['whats_new']),
      androidUrl: (map['android_url'] ?? map['play_store_url'] ?? '').toString().trim(),
      iosUrl: (map['ios_url'] ?? map['app_store_url'] ?? '').toString().trim(),
      isUpdateEnabled: map['is_update_enabled'] as bool? ?? map['isUpdateEnabled'] as bool? ?? true,
    );
  }

  /// Compares two semver strings (e.g., '1.2.0' vs '1.0.4').
  /// Returns:
  /// - Negative number if [v1] < [v2]
  /// - Zero if [v1] == [v2]
  /// - Positive number if [v1] > [v2]
  static int compareVersions(String v1, String v2) {
    final clean1 = _cleanVersion(v1);
    final clean2 = _cleanVersion(v2);

    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }

    return 0;
  }

  static String _cleanVersion(String version) {
    var v = version.trim();
    if (v.toLowerCase().startsWith('v')) {
      v = v.substring(1).trim();
    }
    // Strip build metadata (e.g., 1.0.0+1 -> 1.0.0)
    if (v.contains('+')) {
      v = v.split('+').first;
    }
    // Strip prerelease tags (e.g., 1.0.0-beta -> 1.0.0)
    if (v.contains('-')) {
      v = v.split('-').first;
    }
    return v;
  }

  /// Determines the update type needed for the given [installedVersion].
  AppUpdateType getUpdateType(String installedVersion) {
    if (!isUpdateEnabled) {
      return AppUpdateType.none;
    }

    // Check if installed version is older than latest/new version
    if (latestVersion.isNotEmpty &&
        compareVersions(installedVersion, latestVersion) < 0) {
      return isOptional ? AppUpdateType.optional : AppUpdateType.force;
    }

    return AppUpdateType.none;
  }
}
