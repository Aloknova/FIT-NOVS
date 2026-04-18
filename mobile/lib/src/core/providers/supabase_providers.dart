import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return null;
  }

  return Supabase.instance.client;
});

final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);

  if (client == null) {
    yield null;
    return;
  }

  yield client.auth.currentSession;
  yield* client.auth.onAuthStateChange.map((state) => state.session);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider).valueOrNull?.user;
});

