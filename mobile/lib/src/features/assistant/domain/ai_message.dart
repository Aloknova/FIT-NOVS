class AiMessage {
  const AiMessage({
    required this.id,
    required this.userId,
    required this.content,
    required this.isUser,
    required this.createdAt,
    this.metadata,
  });

  final String id;
  final String userId;
  final String content;
  final bool isUser;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  factory AiMessage.fromMap(Map<String, dynamic> map) {
    return AiMessage(
      id: map['id'] as String,
      userId: map['user_id'] ?? map['sender_id'] as String,
      content: map['content'] as String,
      isUser: map['is_user'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
