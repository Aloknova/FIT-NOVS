import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../todo/data/todo_repository.dart';
import '../../todo/presentation/todo_controller.dart';
import '../domain/workout.dart';
import '../data/workout_repository.dart';

final workoutDifficultyFilterProvider = StateProvider<String?>((ref) => null);

final workoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  final difficulty = ref.watch(workoutDifficultyFilterProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;

  if (repository == null) {
    return [];
  }

  return repository.fetchWorkouts(
    difficulty: difficulty,
    profile: profile,
  );
});

final workoutControllerProvider =
    StateNotifierProvider<WorkoutController, AsyncValue<void>>((ref) {
  return WorkoutController(ref);
});

class WorkoutController extends StateNotifier<AsyncValue<void>> {
  WorkoutController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> scheduleWorkoutForToday(Workout workout) async {
    final todoRepository = _ref.read(todoRepositoryProvider);
    final user = _ref.read(currentUserProvider);

    if (todoRepository == null || user == null) {
      state = AsyncError(
        'Sign in before assigning a workout.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    try {
      await todoRepository.createTask(
        userId: user.id,
        taskDate: DateTime.now(),
        title: workout.title,
        description: workout.description,
        category: 'workout',
        pointsReward: 30,
        source: 'manual',
      );
      state = const AsyncData(null);
      _ref.invalidate(dailyTasksProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
