import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Not: Resmi flutterfire dosyaları (google-services.json / firebase_options.dart)
/// eklendiğinde bu fallback'e gerek kalmaz.
class FirebaseBootstrap {
  static const String _defaultApiKey =
      'AIzaSyACU_DzdzT42Ss2u6OoB6dx3I858lZjfvA';
  static const String _defaultProjectId = 'futbot-a33e9';
  static const String _defaultProjectNumber = '230489623296';
  static const String _defaultStorageBucket =
      'futbot-a33e9.firebasestorage.app';
  static const String _defaultAndroidAppId =
      '1:230489623296:android:47791c91a72a9c2e1f01e5';

  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: _defaultApiKey,
  );
  static const String webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'AIzaSyBySD_CwF9h1irVpS_7SzBvyhdJDfqhROA',
  );
  static const String androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: apiKey,
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: _defaultProjectId,
  );
  static const String projectNumber = String.fromEnvironment(
    'FIREBASE_PROJECT_NUMBER',
    defaultValue: _defaultProjectNumber,
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: _defaultStorageBucket,
  );

  // FlutterFire dosyası yoksa dart-define ile override edilebilir.
  static const String androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: _defaultAndroidAppId,
  );
  static const String webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:230489623296:web:05efa7e58a7ac0ef1f01e5',
  );
  static const String iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:230489623296:ios:futbotfallback',
  );
  static const String authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'futbot-a33e9.firebaseapp.com',
  );
  // Firebase Console > Authentication > Sign-in method > Google altındaki
  // "Web client ID" değerini dart-define ile geçin:
  // flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '230489623296-4bdpk2hvu136v7ne40fgqnt8inpgvsjs.apps.googleusercontent.com',
  );

  static bool get hasGoogleServerClientId =>
      googleServerClientId.trim().isNotEmpty;

  static bool get hasWebRuntimeConfig =>
      webApiKey.trim().isNotEmpty &&
      webAppId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty &&
      projectNumber.trim().isNotEmpty;

  static FirebaseOptions get currentOptions {
    if (kIsWeb) {
      if (!hasWebRuntimeConfig) {
        throw StateError(
          'Web Firebase ayari eksik. FIREBASE_WEB_APP_ID ve FIREBASE_WEB_API_KEY degerlerini --dart-define ile gec.',
        );
      }
      return const FirebaseOptions(
        apiKey: webApiKey,
        appId: webAppId,
        messagingSenderId: projectNumber,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: projectNumber,
          projectId: projectId,
          storageBucket: storageBucket,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: apiKey,
          appId: iosAppId,
          messagingSenderId: projectNumber,
          projectId: projectId,
          storageBucket: storageBucket,
          iosBundleId: 'com.example.flutterapp',
        );
      default:
        return const FirebaseOptions(
          apiKey: apiKey,
          appId: androidAppId,
          messagingSenderId: projectNumber,
          projectId: projectId,
          storageBucket: storageBucket,
        );
    }
  }
}
