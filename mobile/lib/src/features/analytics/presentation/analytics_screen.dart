import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'analytics_controller.dart';
import '../domain/analytics_snapshot.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final _weightController = TextEditingController();
  final _stepsController = TextEditingController();
  final _sleepController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _stepsController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotState = ref.watch(analyticsSnapshotProvider);
    final controllerState = ref.watch(analyticsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          snapshotState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load insights: $error'),
            data: (snapshot) {
              if (snapshot == null) {
                return const Text('Sign in to load analytics.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly insight snapshot',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InsightGrid(snapshot: snapshot),
                  const SizedBox(height: 18),
                  _TrendCard(snapshot: snapshot),
                  const SizedBox(height: 18),
                  _ProgressLogsCard(snapshot: snapshot),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick progress log',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save today\'s weight, steps, and sleep so your analytics become more personal.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stepsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Steps',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sleepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sleep (minutes)',
                  ),
                ),
                if (controllerState.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        controllerState.isLoading ? null : _saveProgressLog,
                    child: const Text('Save today\'s log'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgressLog() async {
    await ref.read(analyticsControllerProvider.notifier).saveProgressLog(
          weightKg: double.tryParse(_weightController.text),
          steps: int.tryParse(_stepsController.text),
          sleepMinutes: int.tryParse(_sleepController.text),
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
            content: Text('Progress log saved. Analytics refreshed.')),
      );

    _weightController.clear();
    _stepsController.clear();
    _sleepController.clear();
  }
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.22,
      children: [
        _InsightCard(
          title: 'Consistency',
          value: '${snapshot.completionRate}%',
          note:
              '${snapshot.completedTasks}/${snapshot.totalTasks} tasks completed this week',
        ),
        _InsightCard(
          title: 'Points',
          value: '${snapshot.userPoints?.totalPoints ?? 0}',
          note: 'Level ${snapshot.userPoints?.level ?? 1}',
        ),
        _InsightCard(
          title: 'Streak',
          value: '${snapshot.userPoints?.currentStreak ?? 0} days',
          note: 'Best: ${snapshot.userPoints?.longestStreak ?? 0} days',
        ),
        _InsightCard(
          title: 'Weight trend',
          value: snapshot.weightChange == null
              ? '--'
              : '${snapshot.weightChange! > 0 ? '+' : ''}${snapshot.weightChange} kg',
          note: 'Based on recent progress logs',
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-day completion trend',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: snapshot.weeklyCompletion
                .map((value) => Expanded(child: _TrendBar(value: value)))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            snapshot.insight,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLogsCard extends StatelessWidget {
  const _ProgressLogsCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent progress logs',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (snapshot.progressLogs.isEmpty)
            Text(
              'No progress logs yet. Save one below to start tracking real trends.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...snapshot.progressLogs.reversed.take(5).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${log.logDate.month}/${log.logDate.day}: '
                      'weight ${log.weightKg?.toStringAsFixed(1) ?? '--'} kg | '
                      'steps ${log.steps ?? '--'} | '
                      'sleep ${log.sleepMinutes ?? '--'} min',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(_getExplanation(title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(note),
          ],
        ),
      ),
    );
  }

  String _getExplanation(String title) {
    switch (title.toLowerCase()) {
      case 'consistency':
        return 'Consistency measures the percentage of your assigned daily tasks you complete each week. Finish your to-dos, workouts, and meals to keep this high!';
      case 'points':
        return 'You earn points for completing workouts (+50), logging meals (+20), and finishing daily tasks (+10). Level up as you accumulate more points.';
      case 'streak':
        return 'Your streak increases by 1 for every consecutive day you complete at least one task or workout. Don\'t break the chain!';
      case 'weight trend':
        return 'This shows how your weight has changed recently based on your progress logs. Regular logging helps build a more accurate trend.';
      default:
        return note;
    }
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = (24 + (value * 1.2)).clamp(24, 140).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}
