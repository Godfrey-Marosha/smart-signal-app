import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';
import 'sign_in_config.dart';

/// Email/Password, Google and Apple sign-in through Firebase Authentication.
///
/// Console setup (see README):
///  * Email/Password: enable it under Authentication > Sign-in method.
///  * Google: enable it, add your debug SHA-1 to the Android app, then run
///    `flutterfire configure` again so google-services.json has the OAuth client.
///  * Apple: needs an Apple Developer account (Services ID + key) entered in the
///    Firebase Apple provider; on iOS also add the "Sign in with Apple" capability.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleReady = false;

  static AppUser? _map(User? u) {
    if (u == null) return null;
    final providers = u.providerData.map((p) => p.providerId).toList();
    final provider = providers.contains('google.com')
        ? 'google'
        : providers.contains('apple.com')
            ? 'apple'
            : 'password';
    return AppUser(uid: u.uid, email: u.email, displayName: u.displayName, provider: provider);
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  bool get isDemo => false;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in error: ${e.code.name} ${e.description}');
      throw AuthFailure(_googleMessage(e));
    }
  }

  static String _googleMessage(GoogleSignInException e) {
    final detail = (e.description ?? '').toLowerCase();
    if (detail.contains('no credential') || detail.contains('no account')) {
      return 'No Google account on this phone. Add one in Settings > Accounts, then try again.';
    }
    if (detail.contains('serverclientid')) return _googleSetup;
    return switch (e.code.name) {
      // A "cancel" straight after picking an account usually means the
      // app's SHA-1 isn't registered in Firebase.
      'canceled' || 'interrupted' =>
        'Google sign-in was cancelled. If you didn\'t cancel it, add this computer\'s SHA-1 to the Android app in Firebase (see README).',
      'clientConfigurationError' || 'providerConfigurationError' => _googleSetup,
      _ => 'Google sign-in failed (${e.code.name}${e.description == null ? '' : ': ${e.description}'}).',
    };
  }

  static const _googleSetup = 'Google sign-in isn\'t set up for this app yet: add the SHA-1 in Firebase and the '
      'web client ID in lib/auth/sign_in_config.dart (see README).';

  static String _message(String code) => switch (code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email. Try signing in.',
        'weak-password' => 'Use a password of at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Please wait a minute and try again.',
        'network-request-failed' => 'No internet connection.',
        'operation-not-allowed' => 'This sign-in method isn\'t enabled in Firebase yet.',
        'account-exists-with-different-credential' => 'This email is already linked to a different sign-in method.',
        'web-context-canceled' || 'canceled' => 'Sign-in was cancelled.',
        _ => 'Sign-in failed ($code). Please try again.',
      };

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> registerWithEmail(String name, String email, String password) => _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        if (name.trim().isNotEmpty) await cred.user?.updateDisplayName(name.trim());
      });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final google = GoogleSignIn.instance;
        if (!_googleReady) {
          // Android needs the *web* OAuth client ID (client_type 3 in
          // google-services.json) to get an ID token Firebase accepts.
          await google.initialize(serverClientId: googleWebClientId.isEmpty ? null : googleWebClientId);
          _googleReady = true;
        }
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw const AuthFailure('Google did not return a sign-in token.');
        await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      });

  @override
  Future<void> signInWithApple() => _guard(() async {
        if (!appleSignInAvailable) {
          throw const AuthFailure('Apple sign-in comes with the iPhone release. Please use Google or email for now.');
        }
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        await _auth.signInWithProvider(provider);
      });

  @override
  Future<void> signOut() async {
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google; nothing to do.
      }
    }
    await _auth.signOut();
  }
}
