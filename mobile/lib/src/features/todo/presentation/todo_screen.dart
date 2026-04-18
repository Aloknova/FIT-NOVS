import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../leaderboard/presentation/leaderboard_controller.dart';
import 'todo_controller.dart';
import '../domain/daily_task.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksState = ref.watch(dailyTasksProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final controllerState = ref.watch(todoControllerProvider);
    final userPoints = ref.watch(currentUserPointsProvider).valueOrNull;
    final completedCount =
        tasksState.valueOrNull?.where((task) => task.isCompleted).length ?? 0;
    final taskCount = tasksState.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily To-Do'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(selectedDate),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your daily personalized checklist. Complete tasks to build streaks and points.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryChip(
                      label: 'Completed',
                      value: '$completedCount / $taskCount',
                    ),
                    _SummaryChip(
                      label: 'Points',
                      value: '${userPoints?.totalPoints ?? 0}',
                    ),
                    _SummaryChip(
                      label: 'Streak',
                      value: '${userPoints?.currentStreak ?? 0} days',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (controllerState.isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(todoControllerProvider.notifier)
                      .generateDailyPlan(),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    taskCount == 0
                        ? 'Generate today\'s plan'
                        : 'Refresh daily plan',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          tasksState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading tasks: $err'),
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No tasks for this day yet.\nGenerate a plan or ask the AI assistant.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: tasks.map((task) => _TaskRow(task: task)).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Task title'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref.read(todoControllerProvider.notifier).addTask(
                        controller.text,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _TaskRow extends ConsumerStatefulWidget {
  const _TaskRow({required this.task});

  final DailyTask task;

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool? _localIsCompleted;

  @override
  void didUpdateWidget(_TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.isCompleted != widget.task.isCompleted) {
      _localIsCompleted = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = _localIsCompleted ?? widget.task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        value: isCompleted,
        onChanged: (_) {
          setState(() {
            _localIsCompleted = !isCompleted;
          });
          ref.read(todoControllerProvider.notifier).toggleTaskStatus(widget.task);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        tileColor: theme.colorScheme.surface,
        title: Text(
          widget.task.title,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.task.description != null &&
                widget.task.description!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.task.description!),
              ),
            const SizedBox(height: 4),
            Text(
              _metaLine(widget.task),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  String _metaLine(DailyTask task) {
    final parts = <String>['+${task.pointsReward} pts', task.category];
    if (task.targetValue != null && task.targetUnit != null) {
      final formattedTarget =
          task.targetValue == task.targetValue!.roundToDouble()
              ? task.targetValue!.toStringAsFixed(0)
              : task.targetValue!.toStringAsFixed(1);
      parts.add('$formattedTarget ${task.targetUnit}');
    }

    return parts.join(' | ');
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
