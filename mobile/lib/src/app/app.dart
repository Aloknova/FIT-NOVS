import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/theme/dark_theme.dart';
import '../core/theme/light_theme.dart';
import '../core/theme/theme.dart';
import '../core/theme/theme_controller.dart';
import 'app_gate.dart';

class FitNovaApp extends ConsumerWidget {
  const FitNovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: AppEnv.appName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themePreference.themeMode,
      home: const AppGate(),
    );
  }
}
