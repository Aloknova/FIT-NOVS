class SocialFriend {
  const SocialFriend({
    required this.id,
    required this.status,
    required this.isIncoming,
    required this.displayName,
    this.email,
  });

  final String id;
  final String status;
  final bool isIncoming;
  final String displayName;
  final String? email;
}

class SocialChallenge {
  const SocialChallenge({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.challengeType,
    required this.visibility,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.rewardPoints,
    required this.isJoined,
    this.description,
    this.targetValue,
    this.targetUnit,
  });

  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String challengeType;
  final String visibility;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final int rewardPoints;
  final bool isJoined;
  final double? targetValue;
  final String? targetUnit;

  factory SocialChallenge.fromMap(
    Map<String, dynamic> map, {
    required bool isJoined,
  }) {
    return SocialChallenge(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      challengeType: map['challenge_type'] as String? ?? 'custom',
      visibility: map['visibility'] as String? ?? 'public',
      status: map['status'] as String? ?? 'draft',
      startDate: DateTime.parse(
        map['start_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      endDate: DateTime.parse(
        map['end_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      rewardPoints: (map['reward_points'] as num?)?.toInt() ?? 0,
      isJoined: isJoined,
      targetValue: (map['target_value'] as num?)?.toDouble(),
      targetUnit: map['target_unit'] as String?,
    );
  }
}

class ChallengeMessage {
  const ChallengeMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
  });

  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String messageType;

  factory ChallengeMessage.fromMap(Map<String, dynamic> map) {
    return ChallengeMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      messageType: map['message_type'] as String? ?? 'text',
    );
  }
}
