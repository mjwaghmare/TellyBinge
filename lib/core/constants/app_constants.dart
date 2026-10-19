class AppConstants {
  AppConstants._();

  // --- App Branding & Metadata ---
  static const String appName = 'PopVerse';
  static const String appCreator = 'MWStudio';
  static const String defaultPackageName = 'com.mwstudio.popverse';
  static const String defaultAppVersion = '1.0.0';
  static const String appLegalese = '© 2026 PopVerse. All rights reserved.';
  static const String appTagline =
      'Your premier destination for movie and TV show tracking, episode countdowns, and watch habits analysis.';

  // --- MWStudio Social Links & Schemes ---
  static const String mwStudioYoutubeUrl =
      'https://youtube.com/@mwstudiooo?si=cLRErdAL_3ursDYV';
  static const String mwStudioYoutubeAppScheme =
      'vnd.youtube://www.youtube.com/@mwstudiooo';
  static const String mwStudioYoutubeIosScheme =
      'youtube://www.youtube.com/@mwstudiooo';

  static const String mwStudioInstagramUrl =
      'https://www.instagram.com/mwstudiooo?stkn=dTdxemNyNnVwdTV3&utm_source=qr';
  static const String mwStudioInstagramAppScheme =
      'instagram://user?username=mwstudiooo';

  static const String mwStudioGithubUrl = 'https://github.com/mjwaghmare';
  static const String mwStudioGithubAppScheme = 'github://';

  static const String mwStudioBuyMeACoffeeUrl =
      'https://buymeacoffee.com/mjwaghmare5';

  // --- Contact & Support ---
  static const String supportEmail = 'mjwaghmare.mtw@gmail.com';
  static const String supportEmailSubjectPrefix = 'PopVerse Support';

  /// Fallback developer/admin email loaded from build configuration or default
  static const String fallbackAdminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: supportEmail,
  );

  // --- Authentication & OAuth ---
  /// Web/Server OAuth Client ID used for Google Sign-In.
  static const String googleServerClientId =
      '236216751300-nvkb8jbs3u64as2jbgt4ad2rlhb9r6c5.apps.googleusercontent.com';

  // --- Store & Attribution ---
  static const String appleAppId = 'YOUR_APPLE_APP_ID';
  static const String playStoreBaseUrl =
      'https://play.google.com/store/apps/details?id=';
  static const String appStoreBaseUrl = 'https://apps.apple.com/app/id';
  static const String playStoreMarketScheme = 'market://details?id=';
  static const String appStoreReviewScheme =
      'itms-apps://itunes.apple.com/app/id';
  static const String playStoreUrl =
      '$playStoreBaseUrl$defaultPackageName';
  static const String appStoreUrl =
      '$appStoreBaseUrl$appleAppId';

  // --- External Services & Media ---
  static const String tmdbWebsiteUrl = 'https://www.themoviedb.org';
  static const String tmdbBaseImageUrl = 'https://image.tmdb.org/t/p/';
  static const String tmdbDefaultBaseUrl =
      'https://restless-bar-82ccpopverse-tmdb-proxy.mjwaghmare.workers.dev/3';
  static const String youtubeWatchUrl = 'https://www.youtube.com/watch?v=';
  static const String youtubeThumbnailBaseUrl = 'https://img.youtube.com/vi/';
  static const String vimeoBaseUrl = 'https://vimeo.com/';
  static const String cloudinaryBaseUploadUrl =
      'https://api.cloudinary.com/v1_1/';
  static const String web3FormsSubmitUrl =
      'https://api.web3forms.com/submit';
  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150';

  /// Builds a full TMDB image URL given a relative path and optional size.
  static String tmdbImageUrl(String path, {String size = 'w500'}) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$tmdbBaseImageUrl$size$cleanPath';
  }

  // --- Onboarding Content ---
  static const String onboardingSkipButton = 'Skip';
  static const String onboardingNextButton = 'Next';
  static const String onboardingStartButton = 'Start tracking';

  static const String onboardingSlide1Badge = 'Tracking';
  static const String onboardingSlide1Title =
      'Track your shows and movies in one place';
  static const String onboardingSlide1Body =
      'Mark episodes watched with a single tap, track your season '
      'progress, and organize your complete movie watchlist.';

  static const String onboardingSlide2Badge = 'Releases';
  static const String onboardingSlide2Title = 'Never miss a premiere or finale';
  static const String onboardingSlide2Body =
      'Follow upcoming air-dates on your schedule and receive smart '
      'alerts the moment new episodes and movies drop.';

  static const String onboardingSlide3Badge = 'Surprise Me';
  static const String onboardingSlide3Title = 'Can’t decide? Roll the dice';
  static const String onboardingSlide3Body =
      'Tap Surprise Me to roll the dice and get instant, personalized '
      'movie and TV show recommendations when you’re stuck.';

  static const String onboardingSlide4Badge = 'Your Stats';
  static const String onboardingSlide4Title =
      'Your watch habits, beautifully visualized';
  static const String onboardingSlide4Body =
      'Track your total watch time across shows and movies, build your '
      'streak, and see your habits grow automatically.';

  static const String onboardingFindingMatchesTitle = 'Finding Matches';
  static const String preferredGenresTitle = 'Preferred Genres';

  // --- App Update Strings ---
  static const String updateAvailableTitle = 'New Update Available';
  static const String forceUpdateMessage =
      'A required update is available to keep $appName running smoothly. Please update to the latest version to continue.';
  static const String optionalUpdateMessage =
      'A new version of $appName is available with performance improvements and new features.';
  static const String updateButtonLabel = 'Update';
  static const String updateNowButtonLabel = 'Update Now';
  static const String updateLaterButtonLabel = 'Later';

  // --- Notifications ---
  static const String notificationReleaseChannelId = 'release_channel';
  static const String notificationReleaseChannelName = 'Release Notifications';
  static const String notificationTestChannelId = 'test_channel';
  static const String notificationTestChannelName = 'Test Notifications';
  static const String notificationAndroidStatusBarIcon = 'ic_stat_notification';
  static const String notificationAndroidLargeIcon = 'ic_notification_large';
}
