class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.rating,
    this.adminNotes,
    this.userEmail,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final int? rating;
  final String? adminNotes;
  final String? userEmail;

  factory FeedbackItem.fromMap(Map<String, dynamic> map) {
    return FeedbackItem(
      id: map['id'] as String,
      subject: map['subject'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      rating: (map['rating'] as num?)?.toInt(),
      adminNotes: map['admin_notes'] as String?,
      userEmail: map['user_email'] as String?,
    );
  }
}
