// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsTLebtFmb7zhQ_odpP9ZOBGpb1jqofnw',
    appId: '1:1041710602592:android:7d1ccfcef22ee1f2486605',
    messagingSenderId: '1041710602592',
    projectId: 'loocal-mark-it-down',
    storageBucket: 'loocal-mark-it-down.firebasestorage.app',
  );

}