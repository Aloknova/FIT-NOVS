import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../leaderboard/data/leaderboard_repository.dart';
import '../../leaderboard/presentation/leaderboard_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../data/todo_repository.dart';
import '../domain/daily_task.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final dailyTasksProvider = FutureProvider<List<DailyTask>>((ref) async {
  final repository = ref.watch(todoRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  if (repository == null || user == null) {
    return [];
  }

  return repository.fetchTasksForDate(user.id, selectedDate);
});

final todoControllerProvider =
    StateNotifierProvider<TodoController, AsyncValue<void>>((ref) {
  return TodoController(ref);
});

class TodoController extends StateNotifier<AsyncValue<void>> {
  TodoController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  TodoRepository get _repository {
    final repository = _ref.read(todoRepositoryProvider);
    if (repository == null) {
      throw StateError('Supabase is not configured.');
    }
    return repository;
  }

  LeaderboardRepository? get _leaderboardRepository {
    return _ref.read(leaderboardRepositoryProvider);
  }

  Future<void> toggleTaskStatus(DailyTask task) async {
    final newStatus = task.isCompleted ? 'pending' : 'completed';

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    try {
      await _repository.updateTaskStatus(task.id, newStatus);
      await _repository.createTaskLog(
        userId: user.id,
        task: task,
        completed: newStatus == 'completed',
      );
      final pointsDelta =
          newStatus == 'completed' ? task.pointsReward : -task.pointsReward;
      if (_leaderboardRepository != null && pointsDelta != 0) {
        await _leaderboardRepository!.applyPointsChange(
          userId: user.id,
          pointsDelta: pointsDelta,
          activityDate: task.taskDate,
        );
        _ref.invalidate(currentUserPointsProvider);
      }
      _ref.invalidate(dailyTasksProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addTask(String title) async {
    final user = _ref.read(currentUserProvider);
    final date = _ref.read(selectedDateProvider);

    if (user == null || title.trim().isEmpty) return;

    state = const AsyncLoading();

    try {
      await _repository.createTask(
        userId: user.id,
        taskDate: date,
        title: title.trim(),
        category: 'custom',
        pointsReward: 10,
      );
      state = const AsyncData(null);
      _ref.invalidate(dailyTasksProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> generateDailyPlan() async {
    final user = _ref.read(currentUserProvider);
    final profile = _ref.read(currentProfileProvider).valueOrNull;
    final date = _ref.read(selectedDateProvider);

    if (user == null || profile == null) {
      state = AsyncError(
        'Sign in and complete onboarding before generating a plan.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    try {
      await _repository.ensureDailyPlan(
        userId: user.id,
        taskDate: date,
        profile: profile,
      );
      await _leaderboardRepository?.fetchOrCreateUserPoints(user.id);
      state = const AsyncData(null);
      _ref.invalidate(dailyTasksProvider);
      _ref.invalidate(currentUserPointsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
