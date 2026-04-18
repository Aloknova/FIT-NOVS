import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/supabase_providers.dart';
import '../domain/feedback_item.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return FeedbackRepository(client);
});

class FeedbackRepository {
  const FeedbackRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedbackItem>> fetchMine(String userId) async {
    final response = await _client
        .from('feedback')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    return (response as List<dynamic>)
        .map((item) => FeedbackItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<FeedbackItem> submit({
    required String userId,
    required String subject,
    required String message,
    int? rating,
  }) async {
    final response = await _client
        .from('feedback')
        .insert({
          'user_id': userId,
          'subject': subject,
          'message': message,
          'rating': rating,
        })
        .select()
        .single();

    return FeedbackItem.fromMap(response);
  }

  Future<List<FeedbackItem>> fetchAdminQueue() async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No authenticated session found.');
    }

    final response = await http.get(
      Uri.parse('${AppEnv.apiBaseUrl}/api/admin/feedback'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Could not load admin feedback: ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => FeedbackItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateAdminStatus({
    required String feedbackId,
    required String status,
    String? adminNotes,
  }) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('No authenticated session found.');
    }

    final response = await http.post(
      Uri.parse('${AppEnv.apiBaseUrl}/api/admin/feedback/$feedbackId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': status,
        'adminNotes': adminNotes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not update feedback: ${response.body}');
    }
  }
}
