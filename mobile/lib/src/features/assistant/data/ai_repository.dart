import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/app_logger.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(supabaseClientProvider));
});

class AiRepository {
  const AiRepository(this._client);

  final SupabaseClient? _client;

  /// Quota enforcement has been removed — all users have unlimited AI access.
  Future<void> enforceDailyQuota({
    required String userId,
    required bool isPremium,
    required String provider,
  }) async {
    // No-op: all features are free, no daily limits apply.
  }


  Future<Map<String, dynamic>> sendMessage({
    required String userId,
    required String message,
    required Map<String, dynamic> profileData,
    List<String> memory = const [],
    String provider = 'groq',
  }) async {
    final url = Uri.parse('${AppEnv.apiBaseUrl}/api/ai/chat');
    AppLogger.action(
      'ai_request_started',
      details: {
        'userId': userId,
        'provider': provider,
      },
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'userId': userId,
        'message': message,
        'memory': memory,
        'profile': profileData,
      }),
    );

    if (response.statusCode != 200) {
      AppLogger.error(
        'AI request failed.',
        scope: 'ai',
        error: response.body,
        details: {
          'userId': userId,
          'provider': provider,
          'statusCode': response.statusCode,
        },
      );
      throw Exception('Failed to get AI response: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'FitNova AI returned an invalid response payload.',
      );
    }

    final normalized = _normalizeResponse(decoded);
    AppLogger.info(
      'AI request completed.',
      scope: 'ai',
      details: {
        'userId': userId,
        'provider': provider,
        'intent': normalized['intent']?.toString() ?? 'unknown',
      },
    );
    return normalized;
  }

  Future<void> logResponse({
    required String userId,
    required String provider,
    required String intent,
    required Map<String, dynamic> requestPayload,
    required Map<String, dynamic> responsePayload,
    required List<dynamic> validatedActions,
  }) async {
    if (_client == null) {
      return;
    }

    await _client.from('ai_logs').insert({
      'user_id': userId,
      'provider': provider,
      'model': responsePayload['model']?.toString() ?? 'unknown',
      'intent': intent,
      'request_payload': requestPayload,
      'response_payload': responsePayload,
      'validated_actions': validatedActions,
      'status': 'success',
      'latency_ms': responsePayload['latency_ms'],
    });
  }

  Future<void> remember({
    required String userId,
    required String summary,
    Map<String, dynamic> payload = const {},
    String memoryType = 'conversation',
  }) async {
    if (_client == null) {
      return;
    }

    await _client.from('ai_memory').insert({
      'user_id': userId,
      'memory_type': memoryType,
      'summary': summary,
      'memory_payload': payload,
      'priority': 2,
    });
  }

  Map<String, dynamic> _normalizeResponse(Map<String, dynamic> payload) {
    final intent = payload['intent']?.toString().trim();
    if (intent == null || intent.isEmpty) {
      throw const FormatException(
        'FitNova AI returned a response without an intent.',
      );
    }

    final summary = payload['summary']?.toString().trim();
    if (summary == null || summary.isEmpty) {
      throw const FormatException(
        'FitNova AI returned a response without a summary.',
      );
    }

    final actions = payload['actions'];
    if (actions != null && actions is! List<dynamic>) {
      throw const FormatException(
        'FitNova AI returned actions in an invalid format.',
      );
    }

    final warnings = payload['warnings'];
    if (warnings != null && warnings is! List<dynamic>) {
      throw const FormatException(
        'FitNova AI returned warnings in an invalid format.',
      );
    }

    return {
      ...payload,
      'intent': intent,
      'summary': summary,
      'actions': actions ?? const [],
      'warnings': (warnings ?? const [])
          .map((item) => item.toString())
          .toList(),
    };
  }
}
