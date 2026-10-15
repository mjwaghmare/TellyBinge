/// Represents the available app launcher icons for Popverse.
enum AppIconOption {
  defaultIcon(
    id: 'default',
    title: 'Original',
    subtitle: 'Classic Popverse',
    isPremium: false,
    iosIconName: null,
    androidAliasSuffix: null,
    androidAliasName: null,
    previewAsset: 'assets/images/app_icons/preview_original.png',
  ),
  cinemaGold(
    id: 'cinema_gold',
    title: 'Cinema Gold',
    subtitle: 'Warm Golden Spotlight',
    isPremium: true,
    iosIconName: 'cinema_gold',
    androidAliasSuffix: 'MainActivityCinemaGold',
    androidAliasName: 'com.mwstudio.popverse.MainActivityCinemaGold',
    previewAsset: 'assets/images/app_icons/preview_cinema_gold.png',
  ),
  neon(
    id: 'neon',
    title: 'Neon',
    subtitle: 'Electric Light Rings',
    isPremium: true,
    iosIconName: 'neon',
    androidAliasSuffix: 'MainActivityNeon',
    androidAliasName: 'com.mwstudio.popverse.MainActivityNeon',
    previewAsset: 'assets/images/app_icons/preview_neon.png',
  ),
  purplePortal(
    id: 'purple_portal',
    title: 'Purple Portal',
    subtitle: 'Cosmic Energy Vortex',
    isPremium: true,
    iosIconName: 'purple_portal',
    androidAliasSuffix: 'MainActivityPurplePortal',
    androidAliasName: 'com.mwstudio.popverse.MainActivityPurplePortal',
    previewAsset: 'assets/images/app_icons/preview_purple_portal.png',
  ),
  midnight(
    id: 'midnight',
    title: 'Midnight',
    subtitle: 'Starry Deep Space',
    isPremium: false,
    iosIconName: 'midnight',
    androidAliasSuffix: 'MainActivityMidnight',
    androidAliasName: 'com.mwstudio.popverse.MainActivityMidnight',
    previewAsset: 'assets/images/app_icons/preview_midnight.png',
  ),
  retroFilm(
    id: 'retro_film',
    title: 'Retro Film',
    subtitle: 'Vintage 35mm Roll',
    isPremium: true,
    iosIconName: 'retro_film',
    androidAliasSuffix: 'MainActivityRetroFilm',
    androidAliasName: 'com.mwstudio.popverse.MainActivityRetroFilm',
    previewAsset: 'assets/images/app_icons/preview_retro_film.png',
  ),
  silverScreen(
    id: 'silver_screen',
    title: 'Silver Screen',
    subtitle: 'Classic Monochrome',
    isPremium: false,
    iosIconName: 'silver_screen',
    androidAliasSuffix: 'MainActivitySilverScreen',
    androidAliasName: 'com.mwstudio.popverse.MainActivitySilverScreen',
    previewAsset: 'assets/images/app_icons/preview_silver_screen.png',
  ),
  popArt(
    id: 'pop_art',
    title: 'Pop Art',
    subtitle: 'Halftone Comic Style',
    isPremium: true,
    iosIconName: 'pop_art',
    androidAliasSuffix: 'MainActivityPopArt',
    androidAliasName: 'com.mwstudio.popverse.MainActivityPopArt',
    previewAsset: 'assets/images/app_icons/preview_pop_art.png',
  ),
  minimal(
    id: 'minimal',
    title: 'Minimal',
    subtitle: 'Clean Studio Aesthetic',
    isPremium: false,
    iosIconName: 'minimal',
    androidAliasSuffix: 'MainActivityMinimal',
    androidAliasName: 'com.mwstudio.popverse.MainActivityMinimal',
    previewAsset: 'assets/images/app_icons/preview_minimal.png',
  ),
  rainbow(
    id: 'rainbow',
    title: 'Rainbow',
    subtitle: 'Prismatic Spectrum',
    isPremium: true,
    iosIconName: 'rainbow',
    androidAliasSuffix: 'MainActivityRainbow',
    androidAliasName: 'com.mwstudio.popverse.MainActivityRainbow',
    previewAsset: 'assets/images/app_icons/preview_rainbow.png',
  ),
  crimson(
    id: 'crimson',
    title: 'Crimson',
    subtitle: 'Deep Ruby Glow',
    isPremium: true,
    iosIconName: 'crimson',
    androidAliasSuffix: 'MainActivityCrimson',
    androidAliasName: 'com.mwstudio.popverse.MainActivityCrimson',
    previewAsset: 'assets/images/app_icons/preview_crimson.png',
  ),
  cosmic(
    id: 'cosmic',
    title: 'Cosmic',
    subtitle: 'Galactic Starlight Spiral',
    isPremium: true,
    iosIconName: 'cosmic',
    androidAliasSuffix: 'MainActivityCosmic',
    androidAliasName: 'com.mwstudio.popverse.MainActivityCosmic',
    previewAsset: 'assets/images/app_icons/preview_cosmic.png',
  );

  static const String defaultApplicationId = 'com.mwstudio.popverse';

  final String id;
  final String title;
  final String subtitle;
  final bool isPremium;
  final String? iosIconName;
  final String? androidAliasSuffix;
  final String? androidAliasName;
  final String previewAsset;

  const AppIconOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isPremium,
    required this.iosIconName,
    required this.androidAliasSuffix,
    required this.androidAliasName,
    required this.previewAsset,
  });

  /// Resolves the fully qualified Android component name for the runtime [applicationId].
  String? resolvedAndroidAlias([String? applicationId]) {
    if (androidAliasSuffix == null) return null;
    final baseAppId = (applicationId != null && applicationId.isNotEmpty)
        ? applicationId
        : defaultApplicationId;
    return '$baseAppId.$androidAliasSuffix';
  }

  /// Resolves an [AppIconOption] from a stored [id], with backward-compatible aliases for previously retired icons.
  static AppIconOption fromId(String? id) {
    if (id == null) return AppIconOption.defaultIcon;
    switch (id) {
      case 'original':
        return AppIconOption.defaultIcon;
      case 'golden_luxe':
        return AppIconOption.cinemaGold;
      case 'neon_pink':
        return AppIconOption.neon;
      case 'ocean_blue':
        return AppIconOption.cosmic;
      case 'sunset':
        return AppIconOption.crimson;
      case 'holographic':
        return AppIconOption.rainbow;
      case 'snow_white':
        return AppIconOption.silverScreen;
    }
    return AppIconOption.values.firstWhere(
      (opt) => opt.id == id,
      orElse: () => AppIconOption.defaultIcon,
    );
  }
}
