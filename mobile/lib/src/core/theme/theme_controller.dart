import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

final themeControllerProvider =
    StateNotifierProvider<ThemeController, AppThemePreference>((ref) {
  final controller = ThemeController();
  controller.load();
  return controller;
});

class ThemeController extends StateNotifier<AppThemePreference> {
  ThemeController() : super(AppThemePreference.system);

  static const _storageKey = 'theme_preference';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_storageKey) ?? 'system';
    state = appThemePreferenceFromStorage(value);
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (state == preference) {
      return;
    }

    state = preference;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, preference.storageValue);

    // TODO: Sync theme preference to Supabase after auth is connected.
  }
}

