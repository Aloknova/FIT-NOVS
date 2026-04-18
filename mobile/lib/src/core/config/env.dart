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
    defaultValue: 'https://ntyqnunwcufqfapkxlwk.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50eXFudW53Y3VmcWZhcGt4bHdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMDc0MzcsImV4cCI6MjA5MTY4MzQzN30.GY4Hc5GPKuPa4Uo08Nk1YrT1WzZz6Fz2IOQT7OmuHnY',
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
