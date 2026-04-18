import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../../../core/providers/supabase_providers.dart';
import '../domain/social_models.dart';

final socialRepositoryProvider = Provider<SocialRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return SocialRepository(client);
});

class SocialRepository {
  const SocialRepository(this._client);

  final SupabaseClient _client;

  Future<List<SocialFriend>> fetchFriendOverview() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('friends')
          .select('''
            id,
            status,
            requester_id,
            addressee_id,
            requester:profiles!friends_requester_id_fkey(full_name, email),
            addressee:profiles!friends_addressee_id_fkey(full_name, email)
          ''')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      final friends = <SocialFriend>[];
      for (final item in response as List<dynamic>) {
        final isIncoming = item['addressee_id'] == userId;
        final otherProfile = isIncoming ? item['requester'] : item['addressee'];
        
        friends.add(SocialFriend(
          id: item['id'] as String,
          status: item['status'] as String,
          isIncoming: isIncoming,
          displayName: otherProfile?['full_name'] as String? ?? 'FitNova member',
          email: otherProfile?['email'] as String?,
        ));
      }
      return friends;
    } catch (e) {
      return [];
    }
  }

  Future<void> requestFriend(String email) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    final profileRes = await _client.from('profiles').select('id').eq('email', email).maybeSingle();
    if (profileRes == null) throw Exception('User not found with that email.');
    
    await _client.from('friends').insert({
      'requester_id': userId,
      'addressee_id': profileRes['id'],
      'status': 'pending',
    });
  }

  Future<void> respondToFriend({
    required String friendshipId,
    required String status,
  }) async {
    await _client.from('friends').update({'status': status}).eq('id', friendshipId);
  }

  Future<List<SocialChallenge>> fetchChallenges(String userId) async {
    final challengesResponse = await _client
        .from('challenges')
        .select()
        .order('start_date', ascending: false)
        .limit(30);

    final joinedResponse = await _client
        .from('challenge_participants')
        .select('challenge_id')
        .eq('user_id', userId);
    final joinedIds = (joinedResponse as List<dynamic>)
        .map((item) => item['challenge_id'] as String)
        .toSet();

    return (challengesResponse as List<dynamic>)
        .map(
          (item) => SocialChallenge.fromMap(
            item as Map<String, dynamic>,
            isJoined: joinedIds.contains(item['id']),
          ),
        )
        .toList();
  }

  Future<void> createChallenge({
    required String userId,
    required String title,
    required String challengeType,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String visibility = 'public',
    double? targetValue,
    String? targetUnit,
    int rewardPoints = 120,
  }) async {
    final created = await _client
        .from('challenges')
        .insert({
          'creator_id': userId,
          'title': title,
          'description': description,
          'challenge_type': challengeType,
          'target_value': targetValue,
          'target_unit': targetUnit,
          'reward_points': rewardPoints,
          'visibility': visibility,
          'start_date': _dateOnly(startDate),
          'end_date': _dateOnly(endDate),
          'status': 'active',
        })
        .select('id')
        .single();

    await joinChallenge(
      challengeId: created['id'] as String,
      userId: userId,
    );
  }

  Future<void> joinChallenge({
    required String challengeId,
    required String userId,
  }) async {
    await _client.from('challenge_participants').upsert({
      'challenge_id': challengeId,
      'user_id': userId,
    });
  }

  Future<List<ChallengeMessage>> fetchChallengeMessages(
    String challengeId,
  ) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('challenge_id', challengeId)
        .order('created_at', ascending: true)
        .limit(80);

    return (response as List<dynamic>)
        .map((item) => ChallengeMessage.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendChallengeMessage({
    required String challengeId,
    required String userId,
    required String content,
  }) async {
    await _client.from('messages').insert({
      'sender_id': userId,
      'challenge_id': challengeId,
      'message_type': 'text',
      'content': content,
    });
  }

  Future<void> deleteChallenge(String challengeId) async {
    // RLS / server enforces that only the creator can delete
    await _client.from('challenges').delete().eq('id', challengeId);
  }

  Future<void> deleteMessage(String messageId) async {
    // RLS / server enforces that only the sender can delete
    await _client.from('messages').delete().eq('id', messageId);
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

