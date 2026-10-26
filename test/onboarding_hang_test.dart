import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/auth/auth_service.dart';
import 'package:street_signal/data/demo_repository.dart';
import 'package:street_signal/models/household.dart';
import 'package:street_signal/state/app_state.dart';

/// A server that never answers, like a phone with a bad connection or a
/// Firestore database that hasn't been created yet.
class _SlowRepository extends DemoRepository {
  @override
  Future<void> saveHousehold(Household household) => Completer<void>().future;
}

class _RefusingRepository extends DemoRepository {
  @override
  Future<void> saveHousehold(Household household) async => throw Exception('[cloud_firestore/permission-denied]');
}

void main() {
  testWidgets('a slow save still opens the app instead of spinning forever', (tester) async {
    final state = AppState(auth: DemoAuthService(), repositoryFor: (_) => _SlowRepository());
    await state.init();
    await state.auth.signInWithGoogle();
    await tester.pump();

    var done = false;
    unawaited(state.saveHousehold(Household.demo(uid: state.repo.uid, name: 'T')).then((_) => done = true));
    await tester.pump(const Duration(seconds: 7));
    expect(done, isTrue);
    expect(state.household, isNotNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a refused save reports an error', (tester) async {
    final state = AppState(auth: DemoAuthService(), repositoryFor: (_) => _RefusingRepository());
    await state.init();
    await state.auth.signInWithGoogle();
    await tester.pump();

    Object? error;
    await state.saveHousehold(Household.demo(uid: state.repo.uid, name: 'T')).catchError((Object e) {
      error = e;
    });
    expect(error, isNotNull);
    expect(state.household, isNull);
  });
}
