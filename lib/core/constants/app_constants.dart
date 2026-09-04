class AppConstants {
  AppConstants._();

  /// Fallback developer/admin email loaded from build configuration or default
  static const String fallbackAdminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'mjwaghmare.mtw@gmail.com',
  );
}
