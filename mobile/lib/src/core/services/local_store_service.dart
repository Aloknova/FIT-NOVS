import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final localStoreServiceProvider = Provider<LocalStoreService>((ref) {
  return const LocalStoreService();
});

class LocalStoreService {
  const LocalStoreService();

  static const plannerTasksBoxName = 'planner_tasks';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(plannerTasksBoxName);
  }

  Box<Map> get _plannerTasksBox => Hive.box<Map>(plannerTasksBoxName);

  List<Map<String, dynamic>> readPlannerTaskRecords(String userId) {
    return _plannerTasksBox.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['user_id']?.toString() == userId)
        .toList();
  }

  Future<void> savePlannerTaskRecord(
    String localId,
    Map<String, dynamic> record,
  ) async {
    await _plannerTasksBox.put(localId, record);
  }

  Future<void> deletePlannerTaskRecord(String localId) async {
    await _plannerTasksBox.delete(localId);
  }
}
