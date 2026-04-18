import 'dart:io';

class AppEnv {
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'FitNova',
  );

  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static String get apiBaseUrl {
    const defaultUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defaultUrl.isNotEmpty) return defaultUrl;
    
    // Fallback for production
    return 'https://fitnova-backend-production.up.railway.app';
  }

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const googleOAuthRedirectUrl = String.fromEnvironment(
    'GOOGLE_OAUTH_REDIRECT_URL',
    defaultValue: 'com.fitnova.app://login-callback/',
  );

  static const freeTierAiDailyLimit = int.fromEnvironment(
    'FREE_TIER_AI_DAILY_LIMIT',
    defaultValue: 10,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
