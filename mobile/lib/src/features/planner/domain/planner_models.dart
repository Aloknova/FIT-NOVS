class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    required this.updatedAt,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String content;
  final String source;
  final DateTime updatedAt;
  final List<String> tags;

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    return NoteItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      source: map['source'] as String? ?? 'manual',
      updatedAt: DateTime.parse(
        map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      tags: (map['tags'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class PlannerTaskItem {
  const PlannerTaskItem({
    required this.id,
    required this.remoteId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdByAi,
    required this.isSynced,
    this.description,
    this.dueAt,
    this.updatedAt,
  });

  final String id;
  final String? remoteId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final String status;
  final int priority;
  final bool createdByAi;
  final bool isSynced;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isLocalOnly => remoteId == null;

  factory PlannerTaskItem.fromMap(Map<String, dynamic> map) {
    return PlannerTaskItem(
      id: map['id'] as String,
      remoteId: map['id'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      dueAt: map['due_at'] == null
          ? null
          : DateTime.tryParse(map['due_at'].toString()),
      status: map['status'] as String? ?? 'pending',
      priority: (map['priority'] as num?)?.toInt() ?? 3,
      createdByAi: (map['created_by_ai'] as bool?) ?? false,
      isSynced: true,
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'].toString()),
    );
  }

  PlannerTaskItem copyWith({
    String? id,
    String? remoteId,
    String? title,
    String? description,
    DateTime? dueAt,
    String? status,
    int? priority,
    bool? createdByAi,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return PlannerTaskItem(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdByAi: createdByAi ?? this.createdByAi,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PlannerEventItem {
  const PlannerEventItem({
    required this.id,
    required this.title,
    required this.eventType,
    required this.startAt,
    required this.source,
    this.description,
    this.endAt,
    this.location,
  });

  final String id;
  final String title;
  final String? description;
  final String eventType;
  final DateTime startAt;
  final DateTime? endAt;
  final String? location;
  final String source;

  factory PlannerEventItem.fromMap(Map<String, dynamic> map) {
    return PlannerEventItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      eventType: map['event_type'] as String? ?? 'calendar',
      startAt: DateTime.parse(
        map['start_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      endAt: map['end_at'] == null
          ? null
          : DateTime.tryParse(map['end_at'].toString()),
      location: map['location'] as String?,
      source: map['source'] as String? ?? 'manual',
    );
  }
}

class AlarmItem {
  const AlarmItem({
    required this.id,
    required this.label,
    required this.alarmTime,
    required this.repeatType,
    required this.isEnabled,
    required this.timezone,
    this.repeatDays = const [],
    this.nextTriggerAt,
  });

  final String id;
  final String label;
  final String alarmTime;
  final String repeatType;
  final bool isEnabled;
  final String timezone;
  final List<int> repeatDays;
  final DateTime? nextTriggerAt;

  factory AlarmItem.fromMap(Map<String, dynamic> map) {
    return AlarmItem(
      id: map['id'] as String,
      label: map['label'] as String? ?? '',
      alarmTime: map['alarm_time'] as String? ?? '06:00:00',
      repeatType: map['repeat_type'] as String? ?? 'daily',
      isEnabled: (map['is_enabled'] as bool?) ?? true,
      timezone: map['timezone'] as String? ?? 'UTC',
      repeatDays: (map['repeat_days'] as List<dynamic>? ?? [])
          .map((item) => int.tryParse(item.toString()) ?? 0)
          .toList(),
      nextTriggerAt: map['next_trigger_at'] == null
          ? null
          : DateTime.tryParse(map['next_trigger_at'].toString()),
    );
  }
}
