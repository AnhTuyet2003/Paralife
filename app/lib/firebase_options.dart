import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARp-j27mkUF1s06FX5DFr-75kZytl27cg', // You need to get this from Firebase Console
    appId: '1:164135358030:web:b5f0ded3a4ab2d7673fd1f', // You need to add a web app to get this
    messagingSenderId: '164135358030',
    projectId: 'refmind-d7a75',
    authDomain: 'refmind-d7a75.firebaseapp.com',
    storageBucket: 'refmind-d7a75.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGqDIgTVO-7rg5wCd9l_PgHYpIMeoQSrA', // You need to get this from Firebase Console
    appId: '1:164135358030:android:f372bbdceb69365a73fd1f',
    messagingSenderId: '164135358030',
    projectId: 'refmind-d7a75',
    storageBucket: 'refmind-d7a75.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQb95uNLWBm_u-eR4hoNysHkkx_YjkWVE', // You need to get this from Firebase Console
    appId: '1:164135358030:ios:b6132c724009fdcf73fd1f', // You need to add an iOS app to get this
    messagingSenderId: '164135358030',
    projectId: 'refmind-d7a75',
    storageBucket: 'refmind-d7a75.appspot.com',
    iosBundleId: 'com.refmind.app',
  );
}
