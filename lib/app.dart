import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_state.dart';

class StreetSignalApp extends StatelessWidget {
  const StreetSignalApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Street Signal',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

/// Signed out -> sign in; signed in without a household -> onboarding; else the app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (state.user == null) return const SignInScreen();
    if (state.household == null && state.loadError != null) return const _LoadError();
    if (state.household == null) return const OnboardingScreen();
    return const Shell();
  }
}

/// Shown instead of onboarding when we couldn't check for an existing
/// household, so an offline start never asks people to set up again.
class _LoadError extends StatefulWidget {
  const _LoadError();

  @override
  State<_LoadError> createState() => _LoadErrorState();
}

class _LoadErrorState extends State<_LoadError> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 16),
              Text(state.loadError!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await state.retryLoad();
                        if (mounted) setState(() => _busy = false);
                      },
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Try again'),
              ),
              TextButton(onPressed: _busy ? null : state.signOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
