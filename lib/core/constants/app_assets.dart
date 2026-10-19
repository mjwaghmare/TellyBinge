/// Centralized asset paths for icons, images, and animations.
class AppAssets {
  AppAssets._();

  static const String logo = 'assets/images/logo.png';
  static const String splashLogo = 'assets/images/splash_logo.png';
  static const String googleLogo = 'assets/images/google.png';
  static const String errorDevices = 'assets/images/error_devices.png';
  static const String diceLottie = 'assets/lottie/dice.json';

  /// Bundled local poster assets for the backdrop grid (Onboarding, Login, Auth prompts).
  static const List<String> backdropPosters = [
    'assets/images/posters/game_of_thrones.webp',
    'assets/images/posters/friends.webp',
    'assets/images/posters/the_flash.webp',
    'assets/images/posters/arrow.webp',
    'assets/images/posters/inception.webp',
    'assets/images/posters/interstellar.webp',
    'assets/images/posters/the_dark_knight.webp',
    'assets/images/posters/avengers_infinity_war.webp',
    'assets/images/posters/dune.webp',
    'assets/images/posters/spiderman_no_way_home.webp',
    'assets/images/posters/oppenheimer.webp',
    'assets/images/posters/joker.webp',
    'assets/images/posters/top_gun_maverick.webp',
    'assets/images/posters/the_matrix.webp',
  ];

  /// 12 distinct bundled poster assets for the onboarding matching screen.
  static const List<String> matchingPosters = [
    'assets/images/posters/friends.webp',
    'assets/images/posters/off_campus.webp',
    'assets/images/posters/sex_education.webp',
    'assets/images/posters/chernobyl.webp',
    'assets/images/posters/vincenzo.webp',
    'assets/images/posters/from.webp',
    'assets/images/posters/indias_best_dancer.webp',
    'assets/images/posters/reacher.webp',
    'assets/images/posters/money_heist_berlin.webp',
    'assets/images/posters/when_life_gives_you_tangerines.webp',
    'assets/images/posters/stranger_things.webp',
    'assets/images/posters/my_name.webp',
  ];
}
