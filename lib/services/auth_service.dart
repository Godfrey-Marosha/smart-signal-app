import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this.auth);
  final FirebaseAuth auth;

  Stream<User?> get changes => auth.userChanges();

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register(String name, String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Account creation is complete even if this optional profile update fails.
    try {
      await credential.user!.updateDisplayName(name.trim());
    } on FirebaseAuthException {
      // The user can still access their account and request verification.
    }
  }

  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => auth.signOut();
}

String authErrorMessage(FirebaseAuthException error) => switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' =>
        'The email or password is incorrect.',
      'email-already-in-use' =>
        'An account already uses this email. Try signing in.',
      'weak-password' => 'Choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'operation-not-allowed' =>
        'Email sign-in must be enabled in Firebase Authentication.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'requires-recent-login' => 'Please sign out and sign in again.',
      _ => 'We could not complete this request. Please try again.',
    };
