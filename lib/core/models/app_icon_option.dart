/// Represents the available app launcher icons for Popverse.
enum AppIconOption {
  defaultIcon(
    id: 'default',
    title: 'Default',
    subtitle: 'Classic Popverse',
    isPremium: false,
    iosIconName: null,
    androidAliasSuffix: null,
    androidAliasName: null,
    previewAsset: 'assets/images/app_icons/preview_default.png',
  ),
  midnight(
    id: 'midnight',
    title: 'Midnight',
    subtitle: 'Dark & Platinum',
    isPremium: false,
    iosIconName: 'midnight',
    androidAliasSuffix: 'MainActivityMidnight',
    androidAliasName: 'com.mwstudio.popverse.MainActivityMidnight',
    previewAsset: 'assets/images/app_icons/preview_midnight.png',
  ),
  minimal(
    id: 'minimal',
    title: 'Minimal',
    subtitle: 'Clean Monochrome',
    isPremium: false,
    iosIconName: 'minimal',
    androidAliasSuffix: 'MainActivityMinimal',
    androidAliasName: 'com.mwstudio.popverse.MainActivityMinimal',
    previewAsset: 'assets/images/app_icons/preview_minimal.png',
  ),
  neonPink(
    id: 'neon_pink',
    title: 'Neon Pink',
    subtitle: 'Vibrant Magenta Glow',
    isPremium: true,
    iosIconName: 'neon_pink',
    androidAliasSuffix: 'MainActivityNeonPink',
    androidAliasName: 'com.mwstudio.popverse.MainActivityNeonPink',
    previewAsset: 'assets/images/app_icons/preview_neon_pink.png',
  ),
  goldenLuxe(
    id: 'golden_luxe',
    title: 'Golden Luxe',
    subtitle: 'Black & Pure Gold',
    isPremium: true,
    iosIconName: 'golden_luxe',
    androidAliasSuffix: 'MainActivityGoldenLuxe',
    androidAliasName: 'com.mwstudio.popverse.MainActivityGoldenLuxe',
    previewAsset: 'assets/images/app_icons/preview_golden_luxe.png',
  ),
  oceanBlue(
    id: 'ocean_blue',
    title: 'Ocean Blue',
    subtitle: 'Deep Aqua & Cyan',
    isPremium: true,
    iosIconName: 'ocean_blue',
    androidAliasSuffix: 'MainActivityOceanBlue',
    androidAliasName: 'com.mwstudio.popverse.MainActivityOceanBlue',
    previewAsset: 'assets/images/app_icons/preview_ocean_blue.png',
  ),
  sunset(
    id: 'sunset',
    title: 'Sunset',
    subtitle: 'Warm Coral Glow',
    isPremium: true,
    iosIconName: 'sunset',
    androidAliasSuffix: 'MainActivitySunset',
    androidAliasName: 'com.mwstudio.popverse.MainActivitySunset',
    previewAsset: 'assets/images/app_icons/preview_sunset.png',
  ),
  holographic(
    id: 'holographic',
    title: 'Holographic',
    subtitle: 'Prismatic Rainbow',
    isPremium: true,
    iosIconName: 'holographic',
    androidAliasSuffix: 'MainActivityHolographic',
    androidAliasName: 'com.mwstudio.popverse.MainActivityHolographic',
    previewAsset: 'assets/images/app_icons/preview_holographic.png',
  ),
  snowWhite(
    id: 'snow_white',
    title: 'Snow White',
    subtitle: 'Crisp Silver Light',
    isPremium: true,
    iosIconName: 'snow_white',
    androidAliasSuffix: 'MainActivitySnowWhite',
    androidAliasName: 'com.mwstudio.popverse.MainActivitySnowWhite',
    previewAsset: 'assets/images/app_icons/preview_snow_white.png',
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

  /// Resolves an [AppIconOption] from a stored [id].
  static AppIconOption fromId(String? id) {
    if (id == null) return AppIconOption.defaultIcon;
    return AppIconOption.values.firstWhere(
      (opt) => opt.id == id,
      orElse: () => AppIconOption.defaultIcon,
    );
  }
}
