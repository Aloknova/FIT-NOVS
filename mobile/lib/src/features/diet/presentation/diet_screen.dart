import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../profile/data/profile_repository.dart';
import 'diet_controller.dart';
import '../domain/diet_plan.dart';

class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dietState = ref.watch(dailyDietProvider);
    final selectedDate = ref.watch(dietDateProvider);
    final controllerState = ref.watch(dietControllerProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Plan'),
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
                ref.read(dietDateProvider.notifier).state = picked;
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
                const SizedBox(height: 8),
                Text(
                  profile == null
                      ? 'Generate a plan after completing your profile.'
                      : 'Calories and meals adapt to your goal: ${profile.fitnessGoal ?? 'stay consistent'}.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controllerState.isLoading
                            ? null
                            : () => ref
                                .read(dietControllerProvider.notifier)
                                .generatePlan(),
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('Generate plan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controllerState.isLoading
                            ? null
                            : () => ref
                                .read(dietControllerProvider.notifier)
                                .generatePlan(forceRegenerate: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controllerState.isLoading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          dietState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading diet plan: $err'),
            data: (plan) {
              if (plan == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Text(
                      'No diet plan found for this date.\nTap Generate plan to create one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MacrosCard(plan: plan),
                  const SizedBox(height: 20),
                  Text(
                    'Meals',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (plan.meals.isEmpty)
                    Text(
                      'No meals mapped in this plan.',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    )
                  else
                    ...plan.meals.map(
                      (meal) => _MealCard(
                        mealData: meal as Map<String, dynamic>,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.plan});

  final DietPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              Expanded(
                child: Text(
                  plan.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plan.calorieTarget} kcal',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Macro(
                label: 'Protein',
                value: '${plan.proteinG?.toStringAsFixed(0) ?? '--'}g',
              ),
              _Macro(
                label: 'Carbs',
                value: '${plan.carbsG?.toStringAsFixed(0) ?? '--'}g',
              ),
              _Macro(
                label: 'Fat',
                value: '${plan.fatG?.toStringAsFixed(0) ?? '--'}g',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.mealData});

  final Map<String, dynamic> mealData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String type = mealData['type']?.toString() ?? 'Snack';
    final String food = mealData['food']?.toString() ?? 'Unknown';
    final int? calories = mealData['calories'] as int?;
    final int? proteinG = mealData['protein_g'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.restaurant, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  food,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (proteinG != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$proteinG g protein',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (calories != null)
            Text(
              '$calories kcal',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}
