import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';

/// Service responsible for rasterizing off-screen or preview widget trees
/// (via [RepaintBoundary]) into crisp PNG images and invoking native system sharing.
class ShareCardService {
  ShareCardService._();
  static final ShareCardService instance = ShareCardService._();

  /// Captures the widget subtree identified by [boundaryKey] into PNG byte data.
  /// Uses a high [pixelRatio] (default: 3.0) to ensure high-definition 1080x1920
  /// resolution suitable for social stories (Instagram, WhatsApp, etc.).
  Future<Uint8List?> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('[ShareCardService] RenderRepaintBoundary was null');
        return null;
      }

      // Ensure boundary is painted before capturing
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e, stack) {
      debugPrint('[ShareCardService] Failed to capture widget to PNG: $e\n$stack');
      return null;
    }
  }

  /// Captures the Polaroid card from [boundaryKey], writes it to the app's cache directory,
  /// and opens the native OS share sheet.
  Future<bool> sharePolaroidCard({
    required GlobalKey boundaryKey,
    required String title,
    String? mediaType,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final bytes = await capturePng(boundaryKey, pixelRatio: 3.0);
      if (bytes == null || bytes.isEmpty) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      final filePath =
          '${tempDir.path}/popverse_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      final isMovie = mediaType?.toLowerCase() == 'movie';
      final mediaDescription = isMovie ? 'movie' : 'TV show';
      final mediaEmoji = isMovie ? '🎬' : '📺';

      final shareText =
          'Check out the $mediaDescription "$title" on PopVerse! $mediaEmoji🍿\n\n'
          'Track your favorite movies & shows:\n'
          '🍎 iOS: ${AppConstants.appStoreUrl}\n'
          '🤖 Android: ${AppConstants.playStoreUrl}';

      final shareSubject = isMovie
          ? 'PopVerse Movie • $title'
          : 'PopVerse TV Show • $title';

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: 'image/png', name: '$sanitizedTitle.png'),
          ],
          text: shareText,
          subject: shareSubject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      return result.status != ShareResultStatus.dismissed;
    } catch (e, stack) {
      debugPrint('[ShareCardService] Failed to share polaroid card: $e\n$stack');
      return false;
    }
  }
}
