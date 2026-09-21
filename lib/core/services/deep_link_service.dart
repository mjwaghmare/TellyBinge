import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized service to launch native streaming apps (or web fallbacks)
/// directly to a movie or TV show title from TMDB watch providers.
class DeepLinkService {
  DeepLinkService._();

  /// Canonical TMDB Provider IDs for major global and Indian streaming platforms
  static const int netflixId = 8;
  static const int amazonPrimeId = 9;
  static const int amazonPrimeVideoId = 119;
  static const int hotstarId = 122; // Disney+ Hotstar / JioHotstar
  static const int jioCinemaId = 220; // Merged into JioHotstar
  static const int appleTvId = 2;
  static const int appleTvPlusId = 350;
  static const int disneyPlusId = 337;
  static const int sonyLivId = 237;
  static const int zee5Id = 121;
  static const int hboMaxId = 384;
  static const int maxId = 1899;
  static const int huluId = 15;
  static const int paramountPlusId = 531;
  static const int crunchyrollId = 283;
  static const int peacockId = 386;
  static const int peacockPremiumId = 387;
  static const int youtubeId = 192;
  static const int googlePlayId = 3;

  /// Returns canonical display name for providers (e.g. normalizing JioCinema & Hotstar -> JioHotstar).
  static String normalizeProviderName(int? providerId, String rawName) {
    if (providerId == hotstarId ||
        providerId == jioCinemaId ||
        rawName.toLowerCase().contains('hotstar') ||
        rawName.toLowerCase().contains('jiocinema')) {
      return 'JioHotstar';
    }
    return rawName;
  }

  /// Launches the native streaming app to the given title, falling back to
  /// the provider's web search, JustWatch URL, or browser search.
  static Future<bool> launchProvider({
    required int providerId,
    String? providerName,
    required String title,
    String? fallbackWebUrl,
  }) async {
    final cleanTitle = title.trim();
    final intentUris = _getNativeIntentUris(
      providerId: providerId,
      providerName: providerName,
      title: cleanTitle,
    );
    final webUri = _getWebSearchUri(
      providerId: providerId,
      providerName: providerName,
      title: cleanTitle,
      fallbackWebUrl: fallbackWebUrl,
    );

    // 1. Attempt provider HTTPS web URL first — this triggers
    //    Universal Links (iOS) / App Links (Android) and opens the
    //    native app directly to the search/content page when installed,
    //    or falls back gracefully to the browser when not.
    if (webUri != null) {
      try {
        final launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('DeepLinkService web URL failed for $webUri: $e');
      }
    }

    // 2. Fallback: attempt native custom URI scheme intents
    //    (e.g. nflx://, hotstar://) for older devices/apps.
    for (final intentUri in intentUris) {
      try {
        if (await canLaunchUrl(intentUri)) {
          final launched = await launchUrl(
            intentUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('DeepLinkService native intent failed for $intentUri: $e');
      }
    }

    // 3. Fallback to TMDB-provided link (typically a TMDB watch page)
    if (fallbackWebUrl != null && fallbackWebUrl.trim().isNotEmpty) {
      try {
        final fallbackUri = Uri.tryParse(fallbackWebUrl.trim());
        if (fallbackUri != null && await canLaunchUrl(fallbackUri)) {
          final launched = await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('DeepLinkService fallback link failed: $e');
      }
    }

    // 4. Final safety net: Search Google for the title on that platform
    if (cleanTitle.isNotEmpty &&
        providerName != null &&
        providerName.trim().isNotEmpty) {
      try {
        final searchUrl = Uri.parse(
          'https://www.google.com/search?q=${Uri.encodeComponent('$cleanTitle watch on $providerName')}',
        );
        return await launchUrl(
          searchUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  /// Generates native intent URIs for the given provider.
  static List<Uri> _getNativeIntentUris({
    required int providerId,
    String? providerName,
    required String title,
  }) {
    final query = Uri.encodeComponent(title);
    final nameLower = providerName?.toLowerCase() ?? '';
    final uris = <Uri>[];

    // Netflix
    if (providerId == netflixId || nameLower.contains('netflix')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('nflx://www.netflix.com/search?q=$query'));
      }
      uris.add(Uri.parse('nflx://'));
      return uris;
    }

    // Amazon Prime Video
    if (providerId == amazonPrimeId ||
        providerId == amazonPrimeVideoId ||
        nameLower.contains('prime video') ||
        nameLower.contains('amazon prime')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('primevideo://search?query=$query'));
        uris.add(Uri.parse('aiv://search?query=$query'));
      }
      uris.add(Uri.parse('primevideo://'));
      uris.add(Uri.parse('aiv://'));
      return uris;
    }

    // JioHotstar / Hotstar / JioCinema
    if (providerId == hotstarId ||
        providerId == jioCinemaId ||
        nameLower.contains('hotstar') ||
        nameLower.contains('jiocinema') ||
        nameLower.contains('jiohotstar')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('hotstar://search?q=$query'));
        uris.add(Uri.parse('jiocinema://search?query=$query'));
      }
      uris.add(Uri.parse('hotstar://'));
      uris.add(Uri.parse('jiocinema://'));
      return uris;
    }

    // Apple TV / Apple TV+
    if (providerId == appleTvId ||
        providerId == appleTvPlusId ||
        nameLower.contains('apple tv')) {
      uris.add(Uri.parse('appletv://'));
      return uris;
    }

    // Disney+
    if (providerId == disneyPlusId || nameLower.contains('disney')) {
      uris.add(Uri.parse('disneyplus://'));
      return uris;
    }

    // SonyLIV
    if (providerId == sonyLivId || nameLower.contains('sonyliv')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('sonyliv://search?query=$query'));
      }
      uris.add(Uri.parse('sonyliv://'));
      return uris;
    }

    // Zee5
    if (providerId == zee5Id || nameLower.contains('zee5')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('zee5://search?q=$query'));
      }
      uris.add(Uri.parse('zee5://'));
      return uris;
    }

    // Max / HBO Max
    if (providerId == hboMaxId ||
        providerId == maxId ||
        nameLower.contains('max')) {
      uris.add(Uri.parse('max://'));
      return uris;
    }

    // Hulu
    if (providerId == huluId || nameLower.contains('hulu')) {
      uris.add(Uri.parse('hulu://'));
      return uris;
    }

    // Paramount+
    if (providerId == paramountPlusId || nameLower.contains('paramount')) {
      uris.add(Uri.parse('paramountplus://'));
      return uris;
    }

    // Crunchyroll
    if (providerId == crunchyrollId || nameLower.contains('crunchyroll')) {
      uris.add(Uri.parse('crunchyroll://'));
      return uris;
    }

    // Peacock
    if (providerId == peacockId ||
        providerId == peacockPremiumId ||
        nameLower.contains('peacock')) {
      uris.add(Uri.parse('peacock://'));
      return uris;
    }

    // YouTube / Google Play
    if (providerId == youtubeId ||
        providerId == googlePlayId ||
        nameLower.contains('youtube') ||
        nameLower.contains('google play')) {
      if (title.isNotEmpty) {
        uris.add(Uri.parse('vnd.youtube://results?search_query=$query'));
      }
      uris.add(Uri.parse('vnd.youtube://'));
      return uris;
    }

    return uris;
  }

  /// Generates direct web search URLs for provider platforms.
  static Uri? _getWebSearchUri({
    required int providerId,
    String? providerName,
    required String title,
    String? fallbackWebUrl,
  }) {
    final query = Uri.encodeComponent(title);
    final nameLower = providerName?.toLowerCase() ?? '';

    // Netflix
    if (providerId == netflixId || nameLower.contains('netflix')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.netflix.com/search?q=$query'
            : 'https://www.netflix.com',
      );
    }

    // Amazon Prime Video
    if (providerId == amazonPrimeId ||
        providerId == amazonPrimeVideoId ||
        nameLower.contains('prime video') ||
        nameLower.contains('amazon prime')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$query'
            : 'https://www.primevideo.com',
      );
    }

    // JioHotstar
    if (providerId == hotstarId ||
        providerId == jioCinemaId ||
        nameLower.contains('hotstar') ||
        nameLower.contains('jiocinema') ||
        nameLower.contains('jiohotstar')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.hotstar.com/in/explore?search_query=$query'
            : 'https://www.hotstar.com',
      );
    }

    // Apple TV / Apple TV+
    if (providerId == appleTvId ||
        providerId == appleTvPlusId ||
        nameLower.contains('apple tv')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://tv.apple.com/search?term=$query'
            : 'https://tv.apple.com',
      );
    }

    // Disney+
    if (providerId == disneyPlusId || nameLower.contains('disney')) {
      return Uri.parse('https://www.disneyplus.com');
    }

    // SonyLIV
    if (providerId == sonyLivId || nameLower.contains('sonyliv')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.sonyliv.com/search'
            : 'https://www.sonyliv.com',
      );
    }

    // Zee5
    if (providerId == zee5Id || nameLower.contains('zee5')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.zee5.com/search?q=$query'
            : 'https://www.zee5.com',
      );
    }

    // Max / HBO Max
    if (providerId == hboMaxId ||
        providerId == maxId ||
        nameLower.contains('max')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.max.com/search?q=$query'
            : 'https://www.max.com',
      );
    }

    // Hulu
    if (providerId == huluId || nameLower.contains('hulu')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.hulu.com/search?q=$query'
            : 'https://www.hulu.com',
      );
    }

    // Paramount+
    if (providerId == paramountPlusId || nameLower.contains('paramount')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.paramountplus.com/search/?q=$query'
            : 'https://www.paramountplus.com',
      );
    }

    // Crunchyroll
    if (providerId == crunchyrollId || nameLower.contains('crunchyroll')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.crunchyroll.com/search?q=$query'
            : 'https://www.crunchyroll.com',
      );
    }

    // Peacock
    if (providerId == peacockId ||
        providerId == peacockPremiumId ||
        nameLower.contains('peacock')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.peacocktv.com/search?q=$query'
            : 'https://www.peacocktv.com',
      );
    }

    // YouTube
    if (providerId == youtubeId ||
        providerId == googlePlayId ||
        nameLower.contains('youtube') ||
        nameLower.contains('google play')) {
      return Uri.parse(
        title.isNotEmpty
            ? 'https://www.youtube.com/results?search_query=$query'
            : 'https://www.youtube.com',
      );
    }

    // Return direct TMDB JustWatch fallback link if available
    if (fallbackWebUrl != null && fallbackWebUrl.trim().isNotEmpty) {
      return Uri.tryParse(fallbackWebUrl.trim());
    }

    return null;
  }
}
