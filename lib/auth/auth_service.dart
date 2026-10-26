import 'dart:async';

/// The signed-in person, independent of Firebase so the UI and tests don't care.
class AppUser {
  const AppUser({required this.uid, this.email, this.displayName, this.provider = 'password'});
  final String uid;
  final String? email;
  final String? displayName;

  /// 'password' | 'google' | 'apple' | 'demo'
  final String provider;
}

/// A sign-in problem with a message that can be shown to the user as is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthService {
  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;

  /// True when sign-in is simulated (demo mode and tests).
  bool get isDemo;

  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}

/// Simulated sign-in for demo mode: every method signs in a demo user.
class DemoAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  bool get isDemo => true;

  void _set(AppUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signInWithEmail(String email, String password) async =>
      _set(AppUser(uid: 'demo-user', email: email, provider: 'password'));

  @override
  Future<void> registerWithEmail(String name, String email, String password) async =>
      _set(AppUser(uid: 'demo-user', email: email, displayName: name, provider: 'password'));

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signInWithGoogle() async => _set(const AppUser(uid: 'demo-user', displayName: 'Thandi', provider: 'google'));

  @override
  Future<void> signInWithApple() async => _set(const AppUser(uid: 'demo-user', displayName: 'Thandi', provider: 'apple'));

  @override
  Future<void> signOut() async => _set(null);
}
