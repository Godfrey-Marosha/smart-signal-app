import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/main.dart';
import 'package:street_signal/screens/auth_screen.dart';
import 'package:street_signal/services/auth_service.dart';

void main() {
  test(
    'Email validation rejects malformed input and accepts trimmed email',
    () {
      expect(validateEmail('missing-at.example.com'), isNotNull);
      expect(validateEmail('user@'), isNotNull);
      expect(validateEmail(' neighbour@example.com '), isNull);
    },
  );
  test('Sign in does not impose new registration password requirements', () {
    expect(validatePassword('short', registering: false), isNull);
    expect(validatePassword('short', registering: true), isNotNull);
    expect(validatePassword('', registering: false), isNotNull);
  });
  test('Credential failures use a generic response', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'user-not-found')),
      authErrorMessage(FirebaseAuthException(code: 'wrong-password')),
    );
  });
  testWidgets(
    'Missing configuration shows setup screen without Firebase access',
    (tester) async {
      await tester.pumpWidget(
        const StreetSignalApp(startupError: 'Not configured'),
      );
      expect(find.text('Connect Street Signal'), findsOneWidget);
      expect(find.text('Project: street-signal-app-8f363'), findsOneWidget);
    },
  );
}
