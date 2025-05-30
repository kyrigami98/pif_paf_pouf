// File generated by FlutterFire CLI.
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
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjdsmDEzfdGbAA_zLHvsml_ZWp7FOnx_A',
    appId: '1:425870607429:android:dd7d64b4359d9faf5c0f2c',
    messagingSenderId: '425870607429',
    projectId: 'pif-paf-pouf-7694b',
    databaseURL: 'https://pif-paf-pouf-7694b-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'pif-paf-pouf-7694b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcWpBxuHEMUIZl8mRn67L-RQs7LvNP2SI',
    appId: '1:425870607429:ios:35ca8ed8c963e56b5c0f2c',
    messagingSenderId: '425870607429',
    projectId: 'pif-paf-pouf-7694b',
    databaseURL: 'https://pif-paf-pouf-7694b-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'pif-paf-pouf-7694b.firebasestorage.app',
    iosBundleId: 'com.example.pifPafPouf',
  );

}