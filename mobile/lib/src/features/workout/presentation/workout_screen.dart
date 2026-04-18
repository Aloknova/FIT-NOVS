import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/workout.dart';
import 'workout_controller.dart';

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsState = ref.watch(workoutsProvider);
    final selectedFilter = ref.watch(workoutDifficultyFilterProvider);
    final controllerState = ref.watch(workoutControllerProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended for ${profile?.fitnessGoal ?? 'your goal'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a training track and assign a session to today.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: selectedFilter == null,
                        onSelected: () => ref
                            .read(workoutDifficultyFilterProvider.notifier)
                            .state = null,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Beginner',
                        isSelected: selectedFilter == 'beginner',
                        onSelected: () => ref
                            .read(workoutDifficultyFilterProvider.notifier)
                            .state = 'beginner',
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Intermediate',
                        isSelected: selectedFilter == 'intermediate',
                        onSelected: () => ref
                            .read(workoutDifficultyFilterProvider.notifier)
                            .state = 'intermediate',
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Advanced',
                        isSelected: selectedFilter == 'advanced',
                        onSelected: () => ref
                            .read(workoutDifficultyFilterProvider.notifier)
                            .state = 'advanced',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (controllerState.isLoading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          workoutsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading workouts: $err'),
            data: (workouts) {
              if (workouts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('No workouts found for this difficulty.'),
                  ),
                );
              }

              return Column(
                children: workouts
                    .map(
                      (workout) => _WorkoutCard(
                        workout: workout,
                        onAssign: () => ref
                            .read(workoutControllerProvider.notifier)
                            .scheduleWorkoutForToday(workout),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.onAssign,
  });

  final Workout workout;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  workout.difficulty.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            workout.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${workout.durationMinutes} min | ${workout.goalFocus}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (workout.description != null) ...[
            const SizedBox(height: 12),
            Text(
              workout.description!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (workout.instructions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Session flow',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...workout.instructions.take(3).map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- ${step.toString()}'),
                  ),
                ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: onAssign,
              child: const Text('Assign to today'),
            ),
          ),
        ],
      ),
    );
  }
}
