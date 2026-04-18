import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_branding.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSavingTheme = false;
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final themePreference = ref.watch(themeControllerProvider);
    final currentUser = ref.watch(currentUserProvider);
    final profileState = ref.watch(currentProfileProvider);

    final profile = profileState.valueOrNull;
    final displayName = profile?.displayName ?? 'FitNova User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ─── Header Card ──────────────────────────────────────────────────
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
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.email ?? 'Connected via App',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Fitness Identity ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fitness Identity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              if (profile != null)
                TextButton.icon(
                  onPressed: () => _showEditProfileSheet(context, profile),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          profileState.when(
            loading: () => const _LoadingBox(),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (p) {
              if (p == null) {
                return const Center(child: Text('No profile found.'));
              }
              final bmi = p.bmi ?? p.calculatedBmi;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.flag_rounded,
                          title: 'Goal',
                          value: p.fitnessGoal ?? '--',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.directions_run_rounded,
                          title: 'Activity',
                          value: p.activityLevel ?? '--',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.monitor_weight_rounded,
                          title: 'BMI',
                          value: bmi == null ? '--' : bmi.toStringAsFixed(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.favorite_rounded,
                          title: 'Status',
                          value: p.bmiCategory,
                          highlight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(label: 'Age', value: '${p.age ?? '--'}'),
                        _MiniStat(
                            label: 'Height',
                            value: '${p.heightCm?.toStringAsFixed(0) ?? '--'} cm'),
                        _MiniStat(
                            label: 'Weight',
                            value: '${p.weightKg?.toStringAsFixed(1) ?? '--'} kg'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // ─── Theme Settings ────────────────────────────────────────────────
          Text(
            'App Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<AppThemePreference>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: cs.surface,
                    selectedForegroundColor: cs.onPrimary,
                    selectedBackgroundColor: cs.primary,
                  ),
                  segments: AppThemePreference.values
                      .map(
                        (item) => ButtonSegment<AppThemePreference>(
                          value: item,
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(item.label),
                          ),
                        ),
                      )
                      .toList(),
                  selected: {themePreference},
                  onSelectionChanged: _isSavingTheme
                      ? null
                      : (selection) => _updateThemePreference(selection.first),
                ),
                if (_isSavingTheme) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Support & Links ─────────────────────────────────────────────
          Text(
            'Support',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Reminders',
                  subtitle: 'Manage alarm & notification flows',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminders settings coming soon.')),
                    );
                  },
                ),
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
                _SettingsTile(
                  icon: Icons.star_outline_rounded,
                  title: 'Free Plan',
                  subtitle: 'Enjoy the full FitNova experience.',
                  onTap: () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You are on the free plan.')),
                    );
                  },
                ),
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  title: 'Contact Support',
                  subtitle: AppBranding.supportEmail,
                  onTap: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: AppBranding.supportEmail,
                      queryParameters: {
                        'subject': 'FitNova Support Request'
                      },
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch email client.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Sign Out ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _isSigningOut ? null : _signOut,
              icon: _isSigningOut
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onErrorContainer,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: const Text(
                'Sign out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _updateThemePreference(AppThemePreference preference) async {
    setState(() => _isSavingTheme = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(themeControllerProvider.notifier).setPreference(preference);
      final user = ref.read(currentUserProvider);
      final repository = ref.read(profileRepositoryProvider);
      if (user != null && repository != null) {
        await repository.updateThemePreference(
          userId: user.id,
          themePreference: preference,
        );
        ref.invalidate(currentProfileProvider);
      }
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Theme updated.')));
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) setState(() => _isSavingTheme = false);
    }
  }

  Future<void> _signOut() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    setState(() => _isSigningOut = true);
    try {
      await repository.signOut();
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Error signing out: $error')));
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _showEditProfileSheet(BuildContext context, UserProfile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(profile: profile),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  
  String _goal = 'maintenance';
  String _activity = 'moderate';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.profile.age?.toString() ?? '');
    _heightController = TextEditingController(text: widget.profile.heightCm?.toString() ?? '');
    _weightController = TextEditingController(text: widget.profile.weightKg?.toString() ?? '');
    _goal = widget.profile.fitnessGoal ?? 'maintenance';
    _activity = widget.profile.activityLevel ?? 'moderate';
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final user = ref.read(currentUserProvider);
      if (repo == null || user == null) throw Exception('Auth missing');

      await repo.updateProfile(
        userId: user.id,
        age: int.tryParse(_ageController.text),
        heightCm: double.tryParse(_heightController.text),
        weightKg: double.tryParse(_weightController.text),
        fitnessGoal: _goal,
        activityLevel: _activity,
      );

      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Identity',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _goal,
              decoration: const InputDecoration(labelText: 'Goal', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'weight_loss', child: Text('Weight Loss')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'muscle_gain', child: Text('Muscle Gain')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _goal = val);
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              decoration: const InputDecoration(labelText: 'Activity Level', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'lightly_active', child: Text('Lightly Active')),
                DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'very_active', child: Text('Very Active')),
                DropdownMenuItem(value: 'extra_active', child: Text('Extra Active')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _activity = val);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _isLoading ? null : _save,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? cs.primaryContainer : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlight ? Colors.transparent : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? cs.onPrimaryContainer : cs.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: highlight
                      ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                      : cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: highlight ? cs.onPrimaryContainer : cs.onSurface,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: cs.secondary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.outline),
      onTap: onTap,
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
