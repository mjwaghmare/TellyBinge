// File manually created based on Firebase Console credentials.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCLLGu6119YQBmxLwBfsfJIfu7tdeHRxM0',
    appId: '1:236216751300:android:17549003f35847783de591',
    messagingSenderId: '236216751300',
    projectId: 'tvtimeapp-replica-2026',
    storageBucket: 'tvtimeapp-replica-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDCtf374atqQhY8bPSYjtb3AXk3KTcdRU',
    appId: '1:236216751300:ios:8f52c0a372b5ba3f3de591',
    messagingSenderId: '236216751300',
    projectId: 'tvtimeapp-replica-2026',
    storageBucket: 'tvtimeapp-replica-2026.firebasestorage.app',
    iosBundleId: 'com.mwstudio.popverse',
  );
}
