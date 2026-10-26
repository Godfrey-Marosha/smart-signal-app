import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/sign_in_config.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _run(Future<void> Function(AuthService auth) action) async {
    final auth = AppScope.of(context).auth;
    setState(() => _busy = true);
    try {
      await action(auth);
    } on AuthFailure catch (e) {
      if (mounted) _show(e.message);
    } catch (e) {
      if (mounted) _show('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitEmail() {
    if (!_form.currentState!.validate()) return;
    _run((auth) => _creating
        ? auth.registerWithEmail(_name.text, _email.text, _password.text)
        : auth.signInWithEmail(_email.text, _password.text));
  }

  void _forgotPassword() {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _show('Enter your email above first, then tap "Forgot password?"');
      return;
    }
    _run((auth) async {
      await auth.sendPasswordReset(email);
      if (mounted) _show('Password reset email sent to $email.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDemo = AppScope.of(context).isDemo;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset('assets/branding/icon_1024.png', width: 88, height: 88),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Street Signal', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('The early signal for your street.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 28),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Sign in')),
                        ButtonSegment(value: true, label: Text('Create account')),
                      ],
                      selected: {_creating},
                      onSelectionChanged: (v) => setState(() => _creating = v.first),
                    ),
                    const SizedBox(height: 16),
                    if (_creating) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                      onFieldSubmitted: (_) => _submitEmail(),
                    ),
                    if (!_creating)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
                      )
                    else
                      const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _submitEmail,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_creating ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: theme.textTheme.bodySmall)),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run((auth) => auth.signInWithGoogle()),
                      icon: const _GoogleMark(),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                    if (isDemo || appleSignInAvailable) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _run((auth) => auth.signInWithApple()),
                      icon: const Icon(Icons.apple),
                      label: const Text('Continue with Apple'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      isDemo
                          ? 'Demo mode: any details sign you in. Nothing is sent to a server.'
                          : 'By continuing you agree that Street Signal uses your reports to warn your area. '
                              'Your name and address are never shown to neighbours.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple "G" badge (not the Google logo asset) for the Google button.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Brand.teal, width: 1.5)),
      child: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Brand.teal)),
    );
  }
}
