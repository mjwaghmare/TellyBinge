import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_version_info.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_update_dialog.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String prefSnoozedAt = 'app_update_snoozed_at';
  static const String prefSnoozedVersion = 'app_update_snoozed_version';
  static const int snoozeDurationDays = 7;
  static const Duration resumeThrottleDuration = Duration(hours: 1);

  DateTime? _lastResumeCheckTime;
  bool _isDialogShowing = false;
  bool _isChecking = false;

  /// Fetches remote version metadata from Firestore.
  /// First checks `app_config/version_info`, and falls back to `system_configs/version`.
  Future<AppVersionInfo?> fetchVersionInfo({
    FirebaseFirestore? firestore,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    try {
      final docRef = db.collection('app_config').doc('version_info');
      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await docRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        snapshot = await docRef.get().timeout(timeout);
      }

      if (snapshot.exists && snapshot.data() != null) {
        return AppVersionInfo.fromMap(snapshot.data()!);
      }

      // Fallback collection if app_config is empty
      final fallbackRef = db.collection('system_configs').doc('version');
      DocumentSnapshot<Map<String, dynamic>> fallbackSnapshot;
      try {
        fallbackSnapshot = await fallbackRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        fallbackSnapshot = await fallbackRef.get().timeout(timeout);
      }

      if (fallbackSnapshot.exists && fallbackSnapshot.data() != null) {
        return AppVersionInfo.fromMap(fallbackSnapshot.data()!);
      }

      return null;
    } catch (e) {
      debugPrint('AppUpdateService: Failed to fetch version info: $e');
      return null;
    }
  }

  /// Checks if an optional update is currently snoozed for the given [latestVersion].
  Future<bool> isUpdateSnoozed(
    String latestVersion, {
    SharedPreferences? prefs,
  }) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      final snoozedAtStr = preferences.getString(prefSnoozedAt);
      final snoozedVersion = preferences.getString(prefSnoozedVersion);

      if (snoozedAtStr == null) return false;

      final snoozedAt = DateTime.tryParse(snoozedAtStr);
      if (snoozedAt == null) return false;

      final difference = DateTime.now().toUtc().difference(snoozedAt.toUtc());

      // If less than 7 days have passed AND the user snoozed this same (or higher) version
      if (difference.inDays < snoozeDurationDays) {
        if (snoozedVersion != null &&
            AppVersionInfo.compareVersions(snoozedVersion, latestVersion) >=
                0) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('AppUpdateService: Error reading snooze state: $e');
      return false;
    }
  }

  /// Records a 7-day snooze for the specified [version].
  Future<void> snoozeUpdate(String version, {SharedPreferences? prefs}) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      await preferences.setString(
        prefSnoozedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
      await preferences.setString(prefSnoozedVersion, version);
    } catch (e) {
      debugPrint('AppUpdateService: Failed to save snooze state: $e');
    }
  }

  /// Clears any active snooze.
  Future<void> clearSnooze({SharedPreferences? prefs}) async {
    try {
      final preferences = prefs ?? await SharedPreferences.getInstance();
      await preferences.remove(prefSnoozedAt);
      await preferences.remove(prefSnoozedVersion);
    } catch (e) {
      debugPrint('AppUpdateService: Failed to clear snooze: $e');
    }
  }

  /// Performs the full update check and presents the appropriate dialog if required.
  Future<void> checkAndShowUpdate(
    BuildContext context, {
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
    GlobalKey<NavigatorState>? navKey,
    bool isResume = false,
    bool bypassSnooze = false,
  }) async {
    if (isResume) {
      final now = DateTime.now();
      if (_lastResumeCheckTime != null &&
          now.difference(_lastResumeCheckTime!) < resumeThrottleDuration) {
        return;
      }
      _lastResumeCheckTime = now;
    }

    if (_isDialogShowing || _isChecking) return;
    _isChecking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;

      final versionInfo = await fetchVersionInfo(firestore: firestore);
      if (versionInfo == null || !versionInfo.isUpdateEnabled) {
        _isChecking = false;
        return;
      }

      final updateType = versionInfo.getUpdateType(installedVersion);
      if (updateType == AppUpdateType.none) {
        _isChecking = false;
        return;
      }

      final isForceUpdate = (updateType == AppUpdateType.force);

      // If it's an optional update and not bypassing snooze, check if it's currently snoozed
      if (!isForceUpdate && !bypassSnooze) {
        final snoozed = await isUpdateSnoozed(
          versionInfo.latestVersion,
          prefs: prefs,
        );
        if (snoozed) {
          _isChecking = false;
          return;
        }
      }

      final targetContext =
          navKey?.currentContext ?? (context.mounted ? context : null);
      if (targetContext == null || !targetContext.mounted) {
        _isChecking = false;
        return;
      }

      _isDialogShowing = true;

      if (!targetContext.mounted) {
        _isDialogShowing = false;
        _isChecking = false;
        return;
      }

      await AppUpdateDialog.show(
        targetContext,
        versionInfo: versionInfo,
        installedVersion: installedVersion,
        isForceUpdate: isForceUpdate,
        onUpdate: () async {
          await openStore(versionInfo, packageInfo.packageName);
        },
        onLater: isForceUpdate
            ? null
            : () async {
                await snoozeUpdate(versionInfo.latestVersion, prefs: prefs);
              },
      );
    } catch (e) {
      debugPrint('AppUpdateService: Error in checkAndShowUpdate: $e');
    } finally {
      _isDialogShowing = false;
      _isChecking = false;
    }
  }

  /// Triggered manually from Settings -> Check for Updates.
  Future<void> checkForUpdatesManual(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion = packageInfo.version;

      final versionInfo = await fetchVersionInfo();
      if (!context.mounted) return;

      if (versionInfo == null || !versionInfo.isUpdateEnabled) {
        AppSnackbar.showInfo(
          context,
          'PopVerse is up to date (v$installedVersion)',
        );
        return;
      }

      final updateType = versionInfo.getUpdateType(installedVersion);
      if (updateType == AppUpdateType.none) {
        AppSnackbar.showSuccess(
          context,
          'PopVerse is up to date (v$installedVersion)',
        );
        return;
      }

      await checkAndShowUpdate(context, bypassSnooze: true);
    } catch (e) {
      debugPrint('AppUpdateService: Manual update check failed: $e');
      if (context.mounted) {
        AppSnackbar.showError(
          context,
          'Could not check for updates. Please try again.',
        );
      }
    }
  }

  /// Resolves the store URL and launches it externally.
  Future<void> openStore(AppVersionInfo versionInfo, String packageName) async {
    // Try platform-specific deep links first
    if (defaultTargetPlatform == TargetPlatform.android) {
      final marketUri = Uri.tryParse('market://details?id=$packageName');
      if (marketUri != null) {
        try {
          final launched = await launchUrl(
            marketUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        } catch (_) {}
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS &&
        versionInfo.iosUrl.isNotEmpty) {
      final itmsUrl = versionInfo.iosUrl.replaceFirst(
        'https://',
        'itms-apps://',
      );
      final itmsUri = Uri.tryParse(itmsUrl);
      if (itmsUri != null) {
        try {
          final launched = await launchUrl(
            itmsUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        } catch (_) {}
      }
    }

    String url = '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      url = versionInfo.androidUrl.isNotEmpty
          ? versionInfo.androidUrl
          : 'https://play.google.com/store/apps/details?id=$packageName';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      url = versionInfo.iosUrl.isNotEmpty
          ? versionInfo.iosUrl
          : 'https://apps.apple.com/app/id$packageName';
    } else {
      url = versionInfo.androidUrl.isNotEmpty
          ? versionInfo.androidUrl
          : versionInfo.iosUrl;
    }

    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('AppUpdateService: Could not launch $url: $e');
      }
    }
  }
}
