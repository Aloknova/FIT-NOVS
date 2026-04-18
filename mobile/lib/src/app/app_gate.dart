import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_branding.dart';
import '../core/config/env.dart';
import '../core/providers/supabase_providers.dart';
import '../core/theme/theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/presentation/onboarding_screen.dart';
import 'root_shell.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentProfileProvider, (previous, next) {
      final profile = next.valueOrNull;

      if (profile == null) {
        return;
      }

      final remotePreference =
          appThemePreferenceFromStorage(profile.themePreference);
      final localPreference = ref.read(themeControllerProvider);

      if (remotePreference != localPreference) {
        ref.read(themeControllerProvider.notifier).setPreference(
              remotePreference,
            );
      }
    });

    if (!AppEnv.isSupabaseConfigured) {
      return const _ConfigurationRequiredScreen();
    }

    final sessionState = ref.watch(authSessionProvider);

    return sessionState.when(
      loading: () => const _AppStatusScreen(
        title: 'Connecting FitNova',
        subtitle: 'Checking your secure session and getting the app ready.',
      ),
      error: (error, _) => _AppErrorScreen(
        title: 'Session unavailable',
        message: error.toString(),
        primaryLabel: 'Try again',
        onPrimaryPressed: () => ref.invalidate(authSessionProvider),
      ),
      data: (session) {
        if (session == null) {
          return const AuthScreen();
        }

        final profileState = ref.watch(currentProfileProvider);

        return profileState.when(
          loading: () => const _AppStatusScreen(
            title: 'Loading your profile',
            subtitle:
                'Pulling your goals, preferences, and onboarding state from Supabase.',
          ),
          error: (error, _) => _AppErrorScreen(
            title: 'Profile unavailable',
            message: error.toString(),
            primaryLabel: 'Retry',
            onPrimaryPressed: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            if (profile == null || !profile.onboardingCompleted) {
              return const OnboardingScreen();
            }

            return const RootShell();
          },
        );
      },
    );
  }
}

class _ConfigurationRequiredScreen extends StatelessWidget {
  const _ConfigurationRequiredScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment setup required',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FitNova needs Supabase runtime values before the app can sign in or load data.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    'Run with:\n'
                    '--dart-define=SUPABASE_URL=...\n'
                    '--dart-define=SUPABASE_ANON_KEY=...\n'
                    '--dart-define=GOOGLE_OAUTH_REDIRECT_URL=${AppBranding.androidPackageName}://login-callback/',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppStatusScreen extends StatelessWidget {
  const _AppStatusScreen({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppErrorScreen extends StatelessWidget {
  const _AppErrorScreen({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPrimaryPressed,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
