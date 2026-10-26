import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/main.dart';
import 'package:street_signal/screens/auth_screen.dart';
import 'package:street_signal/services/auth_service.dart';

class TestAuth extends Fake implements FirebaseAuth {
  final controller = StreamController<User?>.broadcast();
  String? email;
  String? password;
  String? resetEmail;
  bool reject = false;
  @override
  Stream<User?> userChanges() => controller.stream;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    if (reject) throw FirebaseAuthException(code: 'invalid-credential');
    controller.add(TestUser());
    return TestCredential();
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
  }

  @override
  Future<void> signOut() async => controller.add(null);
}

class TestCredential extends Fake implements UserCredential {}

class TestUser extends Fake implements User {
  @override
  String get email => 'neighbour@example.com';
  @override
  String get displayName => 'Godfrey Marosha';
  @override
  bool get emailVerified => true;
}

void main() {
  testWidgets('Sign in reaches home, sign out returns to the sign-in form', (
    tester,
  ) async {
    final auth = TestAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(service: AuthService(auth))),
    );
    auth.controller.add(null);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'neighbour@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Godfrey.'), findsOneWidget);
    expect(auth.email, 'neighbour@example.com');
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
  testWidgets('Incorrect credentials stay on form and display an error', (
    tester,
  ) async {
    final auth = TestAuth()..reject = true;
    addTearDown(auth.controller.close);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(service: AuthService(auth))),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'neighbour@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'incorrect',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });
  testWidgets('Password reset sends the entered email', (tester) async {
    final auth = TestAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(service: AuthService(auth))),
    );
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'neighbour@example.com',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Send reset link'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(auth.resetEmail, 'neighbour@example.com');
    expect(
      find.textContaining('If an account uses this email'),
      findsOneWidget,
    );
  });
}
