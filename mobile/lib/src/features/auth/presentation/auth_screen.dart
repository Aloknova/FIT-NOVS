import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_branding.dart';
import 'auth_controller.dart';

enum AuthMode {
  signIn,
  signUp,
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null || !context.mounted) {
        return;
      }

      final message = error is AuthException
          ? error.message
          : 'Something went wrong while trying to authenticate. Please try again.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimal Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppBranding.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: AppBranding.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppBranding.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your minimal AI fitness companion.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                // Form Container
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<AuthMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<AuthMode>(
                            value: AuthMode.signIn,
                            label: Text('Sign in'),
                          ),
                          ButtonSegment<AuthMode>(
                            value: AuthMode.signUp,
                            label: Text('Create account'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: isBusy
                            ? null
                            : (selection) {
                                setState(() {
                                  _mode = selection.first;
                                });
                              },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _mode == AuthMode.signIn
                            ? 'Welcome back'
                            : 'Start your journey',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mode == AuthMode.signIn
                            ? 'Sign in to resume your goals and daily AI plan.'
                            : 'Create your account to get started.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (_mode == AuthMode.signUp) ...[
                              TextFormField(
                                controller: _nameController,
                                enabled: !isBusy,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) {
                                  if (_mode == AuthMode.signUp &&
                                      (value == null || value.trim().length < 2)) {
                                    return 'Enter your full name.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _emailController,
                              enabled: !isBusy,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty || !email.contains('@')) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !isBusy,
                              obscureText: true,
                              autofillHints: _mode == AuthMode.signIn
                                  ? const [AutofillHints.password]
                                  : const [
                                      AutofillHints.newPassword,
                                      AutofillHints.password,
                                    ],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) {
                                if ((value?.length ?? 0) < 6) {
                                  return 'Use at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: isBusy ? null : _submit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    isBusy
                                        ? 'Please wait...'
                                        : _mode == AuthMode.signIn
                                            ? 'Sign in'
                                            : 'Create account',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('or', style: TextStyle(fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isBusy ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Continue with Google'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(authControllerProvider.notifier);

    try {
      if (_mode == AuthMode.signIn) {
        await controller.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (!mounted) {
          return;
        }

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Signed in. Loading your FitNova profile...')),
          );
        return;
      }

      final response = await controller.signUpWithEmail(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      final message = response.session == null
          ? 'Account created. Check your email to verify the account, then sign in.'
          : 'Account created. Let\'s finish your onboarding profile.';

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      // Errors are surfaced through the provider listener.
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Google sign-in started in your browser. Come back to FitNova after approval.',
            ),
          ),
        );
    } catch (_) {
      // Errors are surfaced through the provider listener.
    }
  }
}
