// PARTIALLY-REAL / PARTIALLY-PLACEHOLDER FILE - double check before shipping.
//
// This file stands in for what `flutterfire configure` generates once a
// full cross-platform Firebase project exists. A human already registered an
// Android app under a real Firebase project ("fark-tee") and dropped a real
// `google-services.json` into this repo (now at
// `android/app/google-services.json` - it was originally committed at
// `android/google-services.json`, which the Google Services Gradle plugin
// does NOT read from; it was moved here as part of wiring this feature up,
// otherwise the Android Gradle build would fail outright with a missing-file
// error). The `android` FirebaseOptions below were filled in from that real
// file, so Android push notifications should actually work once the backend
// sends a real FCM message - but this was not verified end-to-end on a
// device as part of this change.
//
// Every other platform (`ios`, `web`, `macos`, `windows`) below is still an
// obvious placeholder - no GoogleService-Info.plist or web/desktop Firebase
// app has been registered yet. A human still needs to:
//   1. Register an iOS (and web/desktop, if needed) app under the same
//      "fark-tee" Firebase project in the Firebase console.
//   2. Run `flutterfire configure` from the app root (requires the
//      FlutterFire CLI: `dart pub global activate flutterfire_cli`) and let
//      it overwrite this whole file with real per-platform values - this is
//      the recommended path even for Android, since it will double check the
//      hand-filled values below rather than trusting this one-off transcription.
//   3. Make sure the generated `GoogleService-Info.plist` lands at
//      `ios/Runner/GoogleService-Info.plist` (flutterfire configure normally
//      does this for you).
//
// Until iOS is done, `Firebase.initializeApp()` on iOS is expected to fail -
// see the try/catch around it in `main.dart`, which logs a warning and
// continues app startup with notifications disabled rather than crashing.
// The same fallback also protects Android in case the hand-filled values
// below turn out to be stale/wrong.
//
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
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run flutterfire configure once a real Firebase project exists.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME_WEB_API_KEY',
    appId: 'REPLACE_ME_WEB_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  // Real values, transcribed from android/app/google-services.json (Firebase
  // project "fark-tee") - see the file-level comment above.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_pHcWJ7oFcrIWjLL0vgUpcTUq_iHCrvg',
    appId: '1:774400406507:android:1eb2281e921b94e175dfae',
    messagingSenderId: '774400406507',
    projectId: 'fark-tee',
    storageBucket: 'fark-tee.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME_IOS_API_KEY',
    appId: 'REPLACE_ME_IOS_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'com.balerion.farkTeeApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME_MACOS_API_KEY',
    appId: 'REPLACE_ME_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosBundleId: 'com.balerion.farkTeeApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME_WINDOWS_API_KEY',
    appId: 'REPLACE_ME_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME.appspot.com',
  );
}
