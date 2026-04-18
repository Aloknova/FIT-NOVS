import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'src/core/config/env.dart';
import 'src/core/services/app_logger.dart';
import 'src/core/services/local_store_service.dart';
import 'src/core/services/local_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    AppLogger.error(
      'Unhandled Flutter framework error.',
      scope: 'crash',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'Unhandled platform error.',
      scope: 'crash',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  await LocalStoreService.initialize();
  await LocalNotificationsService.instance.initialize();
  AppLogger.info('Local services initialized.', scope: 'startup');

  if (AppEnv.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    AppLogger.info('Supabase initialized.', scope: 'startup');
  } else {
    debugPrint(
      'Supabase is not configured yet. Pass --dart-define values before running.',
    );
  }

  runApp(const ProviderScope(child: FitNovaApp()));
}
