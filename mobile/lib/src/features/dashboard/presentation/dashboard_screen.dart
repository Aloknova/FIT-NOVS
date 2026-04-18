import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_branding.dart';
import '../../analytics/presentation/analytics_controller.dart';
import '../../diet/presentation/diet_screen.dart';
import '../../feedback/presentation/feedback_screen.dart';
import '../../health/domain/health_summary.dart';
import '../../health/presentation/health_controller.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../planner/presentation/planner_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../social/presentation/social_screen.dart';
import '../../workout/presentation/workout_screen.dart';

const _motivationalQuotes = [
  "Discipline is doing what you hate to do, but doing it like you love it.",
  "The only bad workout is the one that didn't happen.",
  "What seems impossible today will one day become your warm-up.",
  "Don't stop when you're tired. Stop when you're done.",
  "Your body can stand almost anything. It's your mind that you have to convince.",
  "Success starts with self-discipline.",
  "Push harder than yesterday if you want a different tomorrow.",
  "The hard part isn't getting your body in shape. The hard part is getting your mind in shape.",
  "Small daily improvements are the key to staggering long-term results.",
  "You don't have to be extreme, just consistent.",
  "Strive for progress, not perfection."
];

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<HealthSummary?>>(
      healthSyncControllerProvider,
      (previous, next) {
        if (previous is! AsyncLoading) return;
        final messenger = ScaffoldMessenger.of(context);
        next.whenOrNull(
          data: (summary) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(
                  summary == null || !summary.hasData
                      ? 'Health Connect is ready. No activity data found yet.'
                      : 'Health synced: ${summary.steps} steps and ${summary.sleepMinutes} min sleep.',
                ),
              ));
          },
          error: (error, _) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error.toString())));
          },
        );
      },
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final bmi = profile?.bmi ?? profile?.calculatedBmi;
    final goal = profile?.fitnessGoal ?? 'Stay consistent';
    
    final healthConnectionState = ref.watch(healthConnectionStateProvider);
    final healthSummary = ref.watch(healthTodaySummaryProvider).valueOrNull;
    final healthSyncState = ref.watch(healthSyncControllerProvider);
    final analytics = ref.watch(analyticsSnapshotProvider).valueOrNull;
    final streak = analytics?.userPoints?.currentStreak ?? 0;

    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final quote = _motivationalQuotes[dayOfYear % _motivationalQuotes.length];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          AppBranding.appName,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ─── Motivational Quote ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Momentum Hero Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Focus',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile == null
                      ? 'Complete tasks to build your personalized plan.'
                      : 'Welcome back, ${profile.firstName}. Stay focused on $goal.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HeroStat(label: 'Streak', value: '$streak days'),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _HeroStat(label: 'Goal', value: goal),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _HeroStat(
                      label: 'BMI',
                      value: bmi == null ? '--' : bmi.toStringAsFixed(1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Health Sync Card ────────────────────────────────────────────
          Text(
            'Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _HealthSyncCard(
            connectionState: healthConnectionState,
            summary: healthSummary,
            isSyncing: healthSyncState.isLoading,
            onPrimaryAction: () async {
              final connection = healthConnectionState.valueOrNull;
              if (connection == null || !connection.platformSupported) return;
              if (!connection.healthConnectAvailable) {
                await ref.read(healthSyncControllerProvider.notifier).installHealthConnect();
                return;
              }
              await ref.read(healthSyncControllerProvider.notifier).syncToday();
            },
          ),
          const SizedBox(height: 32),

          // ─── Jump Back In (Grid) ─────────────────────────────────────────
          Text(
            'Explore',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              _ActionTile(
                title: 'Workout',
                subtitle: 'Routines & plans',
                icon: Icons.fitness_center_rounded,
                color: Colors.orange,
                onTap: () => _open(context, const WorkoutScreen()),
              ),
              _ActionTile(
                title: 'Diet',
                subtitle: 'Calories & meals',
                icon: Icons.restaurant_menu_rounded,
                color: Colors.green,
                onTap: () => _open(context, const DietScreen()),
              ),
              _ActionTile(
                title: 'Leaderboard',
                subtitle: 'Compete & rank',
                icon: Icons.emoji_events_rounded,
                color: Colors.amber,
                onTap: () => _open(context, const LeaderboardScreen()),
              ),
              _ActionTile(
                title: 'Social',
                subtitle: 'Friends & chat',
                icon: Icons.groups_2_rounded,
                color: Colors.blue,
                onTap: () => _open(context, const SocialScreen()),
              ),
              _ActionTile(
                title: 'Planner',
                subtitle: 'Tasks & alarms',
                icon: Icons.event_note_rounded,
                color: Colors.purple,
                onTap: () => _open(context, const PlannerScreen()),
              ),
              _ActionTile(
                title: 'Feedback',
                subtitle: 'Help & reports',
                icon: Icons.feedback_rounded,
                color: Colors.teal,
                onTap: () => _open(context, const FeedbackScreen()),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _HealthSyncCard extends StatelessWidget {
  const _HealthSyncCard({
    required this.connectionState,
    required this.summary,
    required this.isSyncing,
    required this.onPrimaryAction,
  });

  final AsyncValue<HealthConnectionState> connectionState;
  final HealthSummary? summary;
  final bool isSyncing;
  final Future<void> Function() onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: connectionState.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('Error loading health connect: $error'),
        data: (connection) {
          final formatter = NumberFormat.decimalPattern();
          final hasSummary = summary != null && summary!.hasData;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.monitor_heart_rounded, color: cs.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Sync',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          connection.statusMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: isSyncing ? null : onPrimaryAction,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                    ),
                    child: isSyncing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(connection.primaryActionLabel),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.directions_walk_rounded,
                      label: 'Steps',
                      value: hasSummary ? formatter.format(summary!.steps) : '--',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Calories',
                      value: hasSummary ? '${summary!.calories.toStringAsFixed(0)} kcal' : '--',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.favorite_rounded,
                      label: 'Heart',
                      value: hasSummary && summary!.heartRate != null
                          ? '${summary!.heartRate!.toStringAsFixed(0)} bpm'
                          : '--',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricPill(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: hasSummary ? '${summary!.sleepMinutes} min' : '--',
                    ),
                  ),
                ],
              ),
              if (hasSummary && summary!.lastSyncedAt != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Last sync: ${DateFormat('hh:mm a').format(summary!.lastSyncedAt!.toLocal())}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasData = value != '--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: hasData 
            ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
            : cs.surfaceContainerHighest.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasData 
              ? cs.outlineVariant.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon, 
                size: 16, 
                color: hasData ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hasData ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.3),
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
