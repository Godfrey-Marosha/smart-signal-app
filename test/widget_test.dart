import 'package:flutter_test/flutter_test.dart';
import 'package:street_signal/app.dart';
import 'package:street_signal/auth/auth_service.dart';
import 'package:street_signal/data/demo_repository.dart';
import 'package:street_signal/state/app_state.dart';

void main() {
  testWidgets('sign in, set up a demo household, reach Home', (tester) async {
    final repo = DemoRepository();
    final state = AppState(auth: DemoAuthService(), repositoryFor: (_) => repo);
    await state.init();
    await tester.pumpWidget(StreetSignalApp(state: state));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your home'), findsOneWidget);

    await tester.tap(find.text('Use demo household'));
    await tester.pumpAndSettle();
    expect(find.text('Next 48 hours'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);

    // Community tab shows the five sectors and pilot posts.
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Prepare'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
  });
}
