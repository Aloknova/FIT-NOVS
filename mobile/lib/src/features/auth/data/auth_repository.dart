import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/supabase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);

  if (client == null) {
    return null;
  }

  return AuthRepository(client);
});

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppEnv.googleOAuthRedirectUrl, // com.fitnova.app://login-callback/
      data: {
        'full_name': fullName,
        'name': fullName,
      },
    );
  }

  Future<void> signInWithGoogle() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AppEnv.googleOAuthRedirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );

    if (!launched) {
      throw const AuthException(
        'Could not launch the Google sign-in flow.',
      );
    }
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
