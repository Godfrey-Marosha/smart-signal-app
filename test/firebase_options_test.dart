import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/firebase_options.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android resolves to the supplied Firebase app', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final options = DefaultFirebaseOptions.currentPlatform;
    expect(options.projectId, 'street-signal-app-8f363');
    expect(options.appId, '1:776502589511:android:97d7cd362e274e05369962');
    expect(options.messagingSenderId, '776502589511');
    expect(options.apiKey, isNotEmpty);
  });

  test('Unregistered platforms cannot reuse Android Firebase settings', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
        () => DefaultFirebaseOptions.currentPlatform, throwsUnsupportedError);
  });
}
