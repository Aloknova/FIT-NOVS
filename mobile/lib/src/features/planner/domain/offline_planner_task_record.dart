import 'planner_models.dart';

class OfflinePlannerTaskRecord {
  const OfflinePlannerTaskRecord({
    required this.localId,
    required this.userId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdByAi,
    required this.synced,
    required this.updatedAt,
    this.remoteId,
    this.description,
    this.dueAt,
    this.pendingAction,
  });

  final String localId;
  final String? remoteId;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final String status;
  final int priority;
  final bool createdByAi;
  final bool synced;
  final String? pendingAction;
  final DateTime updatedAt;

  factory OfflinePlannerTaskRecord.fromMap(Map<String, dynamic> map) {
    return OfflinePlannerTaskRecord(
      localId: map['local_id'] as String,
      remoteId: map['remote_id'] as String?,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      dueAt: map['due_at'] == null
          ? null
          : DateTime.tryParse(map['due_at'].toString()),
      status: map['status'] as String? ?? 'pending',
      priority: (map['priority'] as num?)?.toInt() ?? 3,
      createdByAi: (map['created_by_ai'] as bool?) ?? false,
      synced: (map['synced'] as bool?) ?? false,
      pendingAction: map['pending_action'] as String?,
      updatedAt: DateTime.tryParse(
            map['updated_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  factory OfflinePlannerTaskRecord.fromRemoteTask(
    PlannerTaskItem task, {
    required String userId,
    String? localId,
  }) {
    return OfflinePlannerTaskRecord(
      localId: localId ?? task.id,
      remoteId: task.remoteId ?? task.id,
      userId: userId,
      title: task.title,
      description: task.description,
      dueAt: task.dueAt,
      status: task.status,
      priority: task.priority,
      createdByAi: task.createdByAi,
      synced: true,
      pendingAction: null,
      updatedAt: task.updatedAt ?? DateTime.now(),
    );
  }

  PlannerTaskItem toPlannerTaskItem() {
    return PlannerTaskItem(
      id: localId,
      remoteId: remoteId,
      title: title,
      description: description,
      dueAt: dueAt,
      status: status,
      priority: priority,
      createdByAi: createdByAi,
      isSynced: synced,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'remote_id': remoteId,
      'user_id': userId,
      'title': title,
      'description': description,
      'due_at': dueAt?.toIso8601String(),
      'status': status,
      'priority': priority,
      'created_by_ai': createdByAi,
      'synced': synced,
      'pending_action': pendingAction,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OfflinePlannerTaskRecord copyWith({
    String? remoteId,
    String? title,
    String? description,
    DateTime? dueAt,
    String? status,
    int? priority,
    bool? createdByAi,
    bool? synced,
    String? pendingAction,
    DateTime? updatedAt,
  }) {
    return OfflinePlannerTaskRecord(
      localId: localId,
      remoteId: remoteId ?? this.remoteId,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueAt: dueAt ?? this.dueAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdByAi: createdByAi ?? this.createdByAi,
      synced: synced ?? this.synced,
      pendingAction: pendingAction,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
