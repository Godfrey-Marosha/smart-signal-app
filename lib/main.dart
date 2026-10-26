import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'auth/firebase_auth_service.dart';
import 'data/demo_repository.dart';
import 'data/firestore_repository.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';

/// Live Firebase by default. For an offline demo without Firebase:
///   flutter run --dart-define=DEMO=true
const bool demoMode = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppState state;
  if (demoMode) {
    final demoRepo = DemoRepository();
    state = AppState(auth: DemoAuthService(), repositoryFor: (_) => demoRepo);
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    state = AppState(auth: FirebaseAuthService(), repositoryFor: (user) => FirestoreRepository(user.uid));
  }
  await state.init();
  runApp(StreetSignalApp(state: state));
}
