import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/legal_content.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../domain/user_profile.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _didPrefill = false;
  String _selectedGender = _genderOptions.first;
  String _selectedGoal = _goalOptions.first;
  String _selectedActivity = _activityOptions[1];

  static const _genderOptions = ['Male', 'Female', 'Other'];
  static const _goalOptions = [
    'Lose fat',
    'Build muscle',
    'Improve endurance',
    'Stay consistent',
  ];
  static const _activityOptions = [
    'Beginner',
    'Moderately active',
    'Highly active',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didPrefill) {
      return;
    }

    final user = ref.read(currentUserProvider);
    final metadata = user?.userMetadata ?? const {};
    final defaultName = (metadata['full_name'] ??
            metadata['name'] ??
            user?.email?.split('@').first)
        ?.toString();

    if (defaultName != null && defaultName.trim().isNotEmpty) {
      _fullNameController.text = defaultName.trim();
    }

    _didPrefill = true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(onboardingControllerProvider,
        (previous, next) {
      final error = next.error;
      if (error == null || !context.mounted) {
        return;
      }

      final message = error is AuthException
          ? error.message
          : 'We could not save your profile right now. Please try again.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    final theme = Theme.of(context);
    final onboardingState = ref.watch(onboardingControllerProvider);
    final isBusy = onboardingState.isLoading;
    final themePreference = ref.watch(themeControllerProvider);
    final bmi = UserProfile.calculateBmi(
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              'Let\'s build your plan',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FitNova uses this profile to personalize workouts, diet targets, reminders, and AI coaching.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      enabled: !isBusy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if ((value?.trim().length ?? 0) < 2) {
                          return 'Enter your name.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            enabled: !isBusy,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            validator: (value) {
                              final age = int.tryParse(value ?? '');
                              if (age == null || age < 13 || age > 100) {
                                return '13-100';
                              }

                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.wc_outlined),
                            ),
                            items: _genderOptions
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: isBusy
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      _selectedGender = value;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            enabled: !isBusy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                              prefixIcon: Icon(Icons.height_outlined),
                            ),
                            validator: (value) {
                              final height = double.tryParse(value ?? '');
                              if (height == null ||
                                  height < 80 ||
                                  height > 250) {
                                return '80-250';
                              }

                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            enabled: !isBusy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                            validator: (value) {
                              final weight = double.tryParse(value ?? '');
                              if (weight == null ||
                                  weight < 25 ||
                                  weight > 300) {
                                return '25-300';
                              }

                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ChoiceSection(
                      title: 'Primary goal',
                      options: _goalOptions,
                      value: _selectedGoal,
                      enabled: !isBusy,
                      onChanged: (value) {
                        setState(() {
                          _selectedGoal = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _ChoiceSection(
                      title: 'Activity level',
                      options: _activityOptions,
                      value: _selectedActivity,
                      enabled: !isBusy,
                      onChanged: (value) {
                        setState(() {
                          _selectedActivity = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMI preview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bmi == null
                                ? 'Enter your height and weight to calculate BMI.'
                                : '${bmi.toStringAsFixed(1)} | This is a general wellness metric, not medical advice.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Theme preference',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppThemePreference>(
                      showSelectedIcon: false,
                      segments: AppThemePreference.values
                          .map(
                            (item) => ButtonSegment<AppThemePreference>(
                              value: item,
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                      selected: {themePreference},
                      onSelectionChanged: isBusy
                          ? null
                          : (selection) {
                              ref
                                  .read(themeControllerProvider.notifier)
                                  .setPreference(selection.first);
                            },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isBusy ? null : _saveProfile,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            isBusy
                                ? 'Saving profile...'
                                : 'Complete onboarding',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.health_and_safety_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LegalContent.shortMedicalDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(onboardingControllerProvider.notifier).submitProfile(
            fullName: _fullNameController.text,
            age: int.parse(_ageController.text),
            gender: _selectedGender,
            heightCm: double.parse(_heightController.text),
            weightKg: double.parse(_weightController.text),
            fitnessGoal: _selectedGoal,
            activityLevel: _selectedActivity,
            themePreference: ref.read(themeControllerProvider),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Profile saved. Building your dashboard...')),
        );
    } catch (_) {
      // Errors are surfaced through the provider listener.
    }
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.options,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map(
                (item) => ChoiceChip(
                  label: Text(item),
                  selected: item == value,
                  onSelected: enabled ? (_) => onChanged(item) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
