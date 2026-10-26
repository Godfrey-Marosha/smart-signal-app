import 'package:flutter/foundation.dart';

/// Google: the *Web client* ID of Firebase project street-signal-app-8f363
/// (the Android build also reads it from google-services.json). It ends in
/// `.apps.googleusercontent.com`). Find it in either place:
///  * Firebase console > Authentication > Sign-in method > Google >
///    Web SDK configuration > Web client ID, or
///  * android/app/google-services.json > `oauth_client` with `"client_type": 3`.
/// It is not a secret: paste it as the defaultValue below, or pass it at run time:
///   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '776502589511-9bh34vivbgv57797s3nabm5uebvtenrg.apps.googleusercontent.com',
);

/// Apple needs an Apple Developer account and a Services ID configured in
/// Firebase (see README). Until then the button only shows on iPhone.
/// Turn it on for Android once Apple is configured:
///   flutter run --dart-define=APPLE_ON_ANDROID=true
const bool _appleOnAndroid = bool.fromEnvironment('APPLE_ON_ANDROID');

bool get appleSignInAvailable =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS || _appleOnAndroid;
