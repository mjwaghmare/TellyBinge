import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/cinema_passport.dart';

/// Evaluates a user's movie and TV show diary into a rich Cinema Passport.
///
/// Pure computation derived directly from the in-memory watchlist states,
/// supporting both explicit country metadata and ISO language resolution.
class CinemaPassportService {
  CinemaPassportService._();

  static const Map<String, (String name, String flag)> _countryInfo = {
    'US': ('United States', '🇺🇸'),
    'KR': ('South Korea', '🇰🇷'),
    'JP': ('Japan', '🇯🇵'),
    'GB': ('United Kingdom', '🇬🇧'),
    'IN': ('India', '🇮🇳'),
    'FR': ('France', '🇫🇷'),
    'ES': ('Spain', '🇪🇸'),
    'DE': ('Germany', '🇩🇪'),
    'IT': ('Italy', '🇮🇹'),
    'CN': ('China', '🇨🇳'),
    'MX': ('Mexico', '🇲🇽'),
    'CA': ('Canada', '🇨🇦'),
    'BR': ('Brazil', '🇧🇷'),
    'AU': ('Australia', '🇦🇺'),
    'SE': ('Sweden', '🇸🇪'),
    'DK': ('Denmark', '🇩🇰'),
    'NO': ('Norway', '🇳🇴'),
    'TR': ('Turkey', '🇹🇷'),
    'IE': ('Ireland', '🇮🇪'),
    'TH': ('Thailand', '🇹🇭'),
    'NL': ('Netherlands', '🇳🇱'),
    'NZ': ('New Zealand', '🇳🇿'),
  };

  static const Map<String, String> _languageToCountry = {
    'ko': 'KR',
    'ja': 'JP',
    'hi': 'IN',
    'ta': 'IN',
    'te': 'IN',
    'ml': 'IN',
    'kn': 'IN',
    'pa': 'IN',
    'fr': 'FR',
    'es': 'ES',
    'de': 'DE',
    'it': 'IT',
    'zh': 'CN',
    'cn': 'CN',
    'pt': 'BR',
    'tr': 'TR',
    'sv': 'SE',
    'da': 'DK',
    'no': 'NO',
    'nl': 'NL',
    'th': 'TH',
    'en': 'US',
  };

  static const Set<String> _europeanCountries = {
    'FR', 'GB', 'ES', 'DE', 'IT', 'SE', 'DK', 'NO', 'NL', 'IE',
  };

  /// Evaluates the complete cinema passport for a user.
  static CinemaPassportData evaluate({
    required List<Map<String, dynamic>> movies,
    required List<Map<String, dynamic>> shows,
  }) {
    final Map<String, int> movieCountryCounts = {};
    final Map<String, int> showCountryCounts = {};
    final Map<String, List<DateTime?>> countryTitleDates = {};
    final Map<String, DateTime> countryFirstWatch = {};

    // 1. Process Watched Movies
    final watchedMovies = movies.where((m) => m['isWatched'] == true);
    for (final m in watchedMovies) {
      final code = _resolveCountry(
        countryField: m['origin_country'] ?? m['country'],
        languageField: m['original_language'] ?? m['language'],
        title: m['title']?.toString() ?? '',
      );
      if (code == null) continue;

      movieCountryCounts[code] = (movieCountryCounts[code] ?? 0) + 1;

      final date = _extractDate(m);
      (countryTitleDates[code] ??= []).add(date);
      if (date != null) {
        final first = countryFirstWatch[code];
        if (first == null || date.isBefore(first)) {
          countryFirstWatch[code] = date;
        }
      }
    }

    // 2. Process Watched Shows
    final watchedShows = shows.where((s) {
      final eps = s['watchedEpisodes'];
      final category = s['category'];
      final isFinished = category == 'FINISHED' || category == 'UP_TO_DATE';
      return (eps is Iterable && eps.isNotEmpty) || isFinished;
    });

    for (final s in watchedShows) {
      final code = _resolveCountry(
        countryField: s['origin_country'] ?? s['country'],
        languageField: s['original_language'] ?? s['language'],
        title: s['name']?.toString() ?? '',
      );
      if (code == null) continue;

      showCountryCounts[code] = (showCountryCounts[code] ?? 0) + 1;

      final date = _extractDate(s);
      (countryTitleDates[code] ??= []).add(date);
      if (date != null) {
        final first = countryFirstWatch[code];
        if (first == null || date.isBefore(first)) {
          countryFirstWatch[code] = date;
        }
      }
    }

    // 3. Build Country Visits
    final allCodes = {...movieCountryCounts.keys, ...showCountryCounts.keys};
    final List<CountryVisit> countryVisits = [];

    for (final code in allCodes) {
      final mCount = movieCountryCounts[code] ?? 0;
      final sCount = showCountryCounts[code] ?? 0;
      if (mCount + sCount == 0) continue;

      final info = _countryInfo[code] ?? (code, '🌐');
      countryVisits.add(
        CountryVisit(
          code: code,
          name: info.$1,
          flagEmoji: info.$2,
          movieCount: mCount,
          showCount: sCount,
        ),
      );
    }

    countryVisits.sort((a, b) => b.totalTitles.compareTo(a.totalTitles));

    // 4. Build Authentic Passport Stamps with Accurate Qualification Dates
    final krCount = (movieCountryCounts['KR'] ?? 0) + (showCountryCounts['KR'] ?? 0);
    final jpCount = (movieCountryCounts['JP'] ?? 0) + (showCountryCounts['JP'] ?? 0);
    final usCount = (movieCountryCounts['US'] ?? 0) + (showCountryCounts['US'] ?? 0);
    final frCount = (movieCountryCounts['FR'] ?? 0) + (showCountryCounts['FR'] ?? 0);
    final inCount = (movieCountryCounts['IN'] ?? 0) + (showCountryCounts['IN'] ?? 0);
    final gbCount = (movieCountryCounts['GB'] ?? 0) + (showCountryCounts['GB'] ?? 0);

    final euroVisited = countryVisits
        .where((c) => _europeanCountries.contains(c.code))
        .length;
    final totalUniqueCountries = countryVisits.length;

    String? getCountryUnlockDate(String code, int requiredCount, bool isUnlocked) {
      if (!isUnlocked) return null;
      final titleDates = countryTitleDates[code];
      if (titleDates == null || titleDates.length < requiredCount) return null;
      if (titleDates.any((d) => d == null)) return null;

      final nonNullDates = titleDates.cast<DateTime>().toList()..sort();
      return _formatDate(nonNullDates[requiredCount - 1]);
    }

    String? getEuroUnlockDate(int requiredCount, bool isUnlocked) {
      if (!isUnlocked) return null;
      final visitedEuroCodes = countryVisits
          .where((c) => _europeanCountries.contains(c.code))
          .map((c) => c.code)
          .toList();
      if (visitedEuroCodes.length < requiredCount) return null;

      final euroDates = <DateTime>[];
      for (final c in visitedEuroCodes) {
        final titleDates = countryTitleDates[c];
        if (titleDates == null || titleDates.any((d) => d == null)) return null;
        final firstDate = countryFirstWatch[c];
        if (firstDate == null) return null;
        euroDates.add(firstDate);
      }
      euroDates.sort();
      return _formatDate(euroDates[requiredCount - 1]);
    }

    String? getGlobeUnlockDate(int requiredCount, bool isUnlocked) {
      if (!isUnlocked || countryVisits.length < requiredCount) return null;

      final globeDates = <DateTime>[];
      for (final c in countryVisits) {
        final titleDates = countryTitleDates[c.code];
        if (titleDates == null || titleDates.any((d) => d == null)) return null;
        final firstDate = countryFirstWatch[c.code];
        if (firstDate == null) return null;
        globeDates.add(firstDate);
      }
      globeDates.sort();
      return _formatDate(globeDates[requiredCount - 1]);
    }

    final List<PassportStamp> stamps = [
      PassportStamp(
        id: 'seoul_cinephile',
        title: 'SEOUL CINEPHILE',
        subtitle: 'K-DRAMA DIVISION',
        countryCode: 'KR',
        flagEmoji: '🇰🇷',
        inkColor: AppColors.skyBlue,
        rotationAngle: -0.07,
        requiredCount: 5,
        currentCount: krCount,
        isUnlocked: krCount >= 5,
        unlockedDate: getCountryUnlockDate('KR', 5, krCount >= 5),
        description: 'Watch 5+ Korean films or K-Dramas',
        shape: PassportStampShape.circular,
        entryCode: 'ICN-082',
      ),
      PassportStamp(
        id: 'tokyo_dreams',
        title: 'TOKYO DREAMS',
        subtitle: 'NARITA IMMIGRATION',
        countryCode: 'JP',
        flagEmoji: '🇯🇵',
        inkColor: AppColors.error,
        rotationAngle: 0.06,
        requiredCount: 5,
        currentCount: jpCount,
        isUnlocked: jpCount >= 5,
        unlockedDate: getCountryUnlockDate('JP', 5, jpCount >= 5),
        description: 'Watch 5+ Japanese films or Anime series',
        shape: PassportStampShape.hexagonal,
        entryCode: 'NRT-PERMIT',
      ),
      PassportStamp(
        id: 'hollywood_calling',
        title: 'HOLLYWOOD CALLING',
        subtitle: 'LOS ANGELES • CBP ENTRY',
        countryCode: 'US',
        flagEmoji: '🇺🇸',
        inkColor: AppColors.accentBlue,
        rotationAngle: -0.05,
        requiredCount: 15,
        currentCount: usCount,
        isUnlocked: usCount >= 15,
        unlockedDate: getCountryUnlockDate('US', 15, usCount >= 15),
        description: 'Watch 15+ American films or TV shows',
        shape: PassportStampShape.oval,
        entryCode: 'LAX-CLASS-A',
      ),
      PassportStamp(
        id: 'cannes_vibes',
        title: 'CANNES VIBES',
        subtitle: 'RIVIERA CINEMA PASS',
        countryCode: 'FR',
        flagEmoji: '🇫🇷',
        inkColor: AppColors.goldDark,
        rotationAngle: 0.08,
        requiredCount: 3,
        currentCount: frCount,
        isUnlocked: frCount >= 3,
        unlockedDate: getCountryUnlockDate('FR', 3, frCount >= 3),
        description: 'Watch 3+ French films or series',
        shape: PassportStampShape.roundedRectangle,
        entryCode: 'NCE-FESTIVAL',
      ),
      PassportStamp(
        id: 'mumbai_magic',
        title: 'MUMBAI MAGIC',
        subtitle: 'BOLLYWOOD TERMINAL',
        countryCode: 'IN',
        flagEmoji: '🇮🇳',
        inkColor: AppColors.bronze,
        rotationAngle: -0.06,
        requiredCount: 5,
        currentCount: inCount,
        isUnlocked: inCount >= 5,
        unlockedDate: getCountryUnlockDate('IN', 5, inCount >= 5),
        description: 'Watch 5+ Indian movies or series',
        shape: PassportStampShape.circular,
        entryCode: 'BOM-INSPECT',
      ),
      PassportStamp(
        id: 'london_calling',
        title: 'LONDON CALLING',
        subtitle: 'UK BORDER FORCE',
        countryCode: 'GB',
        flagEmoji: '🇬🇧',
        inkColor: AppColors.primary,
        rotationAngle: 0.05,
        requiredCount: 5,
        currentCount: gbCount,
        isUnlocked: gbCount >= 5,
        unlockedDate: getCountryUnlockDate('GB', 5, gbCount >= 5),
        description: 'Watch 5+ British films or BBC series',
        shape: PassportStampShape.roundedRectangle,
        entryCode: 'LHR-BORDER',
      ),
      PassportStamp(
        id: 'euro_explorer',
        title: 'EURO PASS',
        subtitle: 'SCHENGEN CINEMA',
        countryCode: 'EU',
        flagEmoji: '🇪🇺',
        inkColor: AppColors.success,
        rotationAngle: -0.08,
        requiredCount: 3,
        currentCount: euroVisited,
        isUnlocked: euroVisited >= 3,
        unlockedDate: getEuroUnlockDate(3, euroVisited >= 3),
        description: 'Watch cinema from at least 3 European nations',
        shape: PassportStampShape.roundedRectangle,
        entryCode: 'SCHENGEN-ZONE',
      ),
      PassportStamp(
        id: 'globe_trotter',
        title: 'GLOBE TROTTER',
        subtitle: 'WORLD CINEMA CITIZEN',
        countryCode: 'GLOBAL',
        flagEmoji: '🌍',
        inkColor: AppColors.gold,
        rotationAngle: 0.07,
        requiredCount: 5,
        currentCount: totalUniqueCountries,
        isUnlocked: totalUniqueCountries >= 5,
        unlockedDate: getGlobeUnlockDate(5, totalUniqueCountries >= 5),
        description: 'Watch titles across at least 5 different countries',
        shape: PassportStampShape.circular,
        entryCode: 'UN-PASSPORT',
      ),
    ];

    final int totalTitlesLogged = countryVisits.fold<int>(
      0,
      (sum, c) => sum + c.totalTitles,
    );

    return CinemaPassportData(
      totalCountries: totalUniqueCountries,
      totalTitles: totalTitlesLogged,
      countries: countryVisits,
      stamps: stamps,
    );
  }

  static String? _resolveCountry({
    dynamic countryField,
    dynamic languageField,
    required String title,
  }) {
    // 1. Direct origin_country check
    if (countryField != null) {
      if (countryField is String && countryField.isNotEmpty) {
        final upper = countryField.trim().toUpperCase();
        if (RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return upper;
      } else if (countryField is List && countryField.isNotEmpty) {
        final first = countryField.first?.toString().trim().toUpperCase();
        if (first != null && RegExp(r'^[A-Z]{2}$').hasMatch(first)) return first;
      }
    }

    // 2. Language to Country mapping
    if (languageField != null && languageField is String) {
      final lang = languageField.trim().toLowerCase();
      final mapped = _languageToCountry[lang];
      if (mapped != null) return mapped;
    }

    // 3. Fallback: Return null when no country is resolvable
    return null;
  }

  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd MMM yyyy').format(date).toUpperCase();
  }

  static DateTime? _extractDate(Map<String, dynamic> item) {
    DateTime? parse(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String && val.trim().isNotEmpty) {
        return DateTime.tryParse(val.trim());
      }
      return null;
    }

    return parse(item['watchedAt']) ?? parse(item['addedAt']);
  }
}
