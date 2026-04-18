import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  AuthRepository get _repository {
    final repository = _ref.read(authRepositoryProvider);

    if (repository == null) {
      throw StateError(
        'Supabase is not configured yet. Add the app environment values before running FitNova.',
      );
    }

    return repository;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final response = await _repository.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      state = const AsyncData(null);
      return response;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final response = await _repository.signUpWithEmail(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
      );
      state = const AsyncData(null);
      return response;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    try {
      await _repository.signInWithGoogle();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
