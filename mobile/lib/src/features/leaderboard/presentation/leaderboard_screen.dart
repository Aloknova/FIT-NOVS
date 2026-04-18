import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'leaderboard_controller.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userPointsState = ref.watch(currentUserPointsProvider);
    final entriesState = ref.watch(leaderboardEntriesProvider);
    final period = ref.watch(leaderboardPeriodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          userPointsState.when(
            loading: () => const _Panel(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _Panel(
              child: Text('Could not load your points yet: $error'),
            ),
            data: (points) {
              if (points == null) {
                return const _Panel(
                  child: Text('Sign in to track points, streaks, and levels.'),
                );
              }

              return _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your momentum',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatChip(
                            label: 'Points', value: '${points.totalPoints}'),
                        _StatChip(label: 'Level', value: '${points.level}'),
                        _StatChip(
                          label: 'Current streak',
                          value: '${points.currentStreak} days',
                        ),
                        _StatChip(
                          label: 'Best streak',
                          value: '${points.longestStreak} days',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ranking period',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<String>(
                      value: 'weekly',
                      label: Text('Weekly'),
                    ),
                    ButtonSegment<String>(
                      value: 'monthly',
                      label: Text('Monthly'),
                    ),
                    ButtonSegment<String>(
                      value: 'all_time',
                      label: Text('All-time'),
                    ),
                  ],
                  selected: {period},
                  onSelectionChanged: (selection) {
                    ref.read(leaderboardPeriodProvider.notifier).state =
                        selection.first;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          entriesState.when(
            loading: () => const _Panel(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _Panel(
              child: Text('Could not load leaderboard data yet: $error'),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const _Panel(
                  child: Text(
                    'No public leaderboard snapshot is available yet. Your personal points and streaks are live now.',
                  ),
                );
              }

              return Column(
                children: entries
                    .map(
                      (entry) => _LeaderboardRow(
                        rank: entry.rank,
                        name: entry.displayName,
                        score: entry.score,
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.score,
  });

  final int rank;
  final String name;
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '$rank',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$score pts',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
