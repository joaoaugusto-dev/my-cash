import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static String get supabaseUrl => _required('SUPABASE_URL');

  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');

  static String get apiBaseUrl => _required('API_BASE_URL');

  static String get googleWebClientId => _required('GOOGLE_WEB_CLIENT_ID');

  static String get oauthRedirectScheme =>
      dotenv.maybeGet('OAUTH_REDIRECT_SCHEME') ?? 'mycash';

  static String get oauthRedirectHost =>
      dotenv.maybeGet('OAUTH_REDIRECT_HOST') ?? 'auth-callback';

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }

    return value.trim();
  }
}
