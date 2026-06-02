import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AppEnv {
  static String get appEnvironment => _appEnvironment;

  static bool get isProduction => appEnvironment == 'production';

  static String get supabaseUrl => _required('SUPABASE_URL', _supabaseUrl);

  static String get supabaseAnonKey =>
      _required('SUPABASE_ANON_KEY', _supabaseAnonKey);

  static String get apiBaseUrl => _required('API_BASE_URL', _apiBaseUrl);

  static String get googleWebClientId => _googleWebClientId;

  static String? validateBootstrapConfig() {
    final missing = <String>[];
    if (_supabaseUrl == null) {
      missing.add('SUPABASE_URL');
    }
    if (_supabaseAnonKey == null) {
      missing.add('SUPABASE_ANON_KEY');
    }
    if (_apiBaseUrl == null) {
      missing.add('API_BASE_URL');
    }

    if (missing.isEmpty) {
      return _validateRuntimeConfig();
    }

    return 'Configuração ausente: ${missing.join(', ')}. '
        'Defina via --dart-define ou arquivo .env no build.';
  }

  static String get _appEnvironment =>
      _resolve('APP_ENV') ?? _safeDotEnvGet('APP_ENV') ?? 'development';

  static String? get _supabaseUrl =>
      _resolve('SUPABASE_URL') ?? _safeDotEnvGet('SUPABASE_URL');

  static String? get _supabaseAnonKey =>
      _resolve('SUPABASE_ANON_KEY') ?? _safeDotEnvGet('SUPABASE_ANON_KEY');

  static String? get _apiBaseUrl =>
      _resolve('API_BASE_URL') ?? _safeDotEnvGet('API_BASE_URL');

  static String get _googleWebClientId =>
      _resolve('GOOGLE_WEB_CLIENT_ID') ??
      _safeDotEnvGet('GOOGLE_WEB_CLIENT_ID') ??
      '';

  static String? _resolve(String key) {
    switch (key) {
      case 'SUPABASE_URL':
        return _sanitize(const String.fromEnvironment('SUPABASE_URL'));
      case 'SUPABASE_ANON_KEY':
        return _sanitize(const String.fromEnvironment('SUPABASE_ANON_KEY'));
      case 'API_BASE_URL':
        return _sanitize(const String.fromEnvironment('API_BASE_URL'));
      case 'GOOGLE_WEB_CLIENT_ID':
        return _sanitize(const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'));
      case 'APP_ENV':
        return _sanitize(const String.fromEnvironment('APP_ENV'));
      default:
        if (kDebugMode) {
          debugPrint('Unknown config key requested: $key');
        }
        return null;
    }
  }

  static String? _safeDotEnvGet(String key) {
    try {
      return _sanitize(dotenv.maybeGet(key));
    } catch (_) {
      return null;
    }
  }

  static String _required(String key, String? value) {
    if (value == null) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }

  static String? _sanitize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _validateRuntimeConfig() {
    final env = appEnvironment;
    if (env != 'development' && env != 'production') {
      return 'APP_ENV inválido: $env. Use development ou production.';
    }

    final apiValidation = _validateUrl(
      key: 'API_BASE_URL',
      value: _apiBaseUrl!,
      mustUseHttps: isProduction,
      rejectLocal: isProduction,
    );
    if (apiValidation != null) {
      return apiValidation;
    }

    final supabaseValidation = _validateUrl(
      key: 'SUPABASE_URL',
      value: _supabaseUrl!,
      mustUseHttps: isProduction,
      rejectLocal: isProduction,
    );
    if (supabaseValidation != null) {
      return supabaseValidation;
    }

    return null;
  }

  static String? _validateUrl({
    required String key,
    required String value,
    required bool mustUseHttps,
    required bool rejectLocal,
  }) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '$key inválido: defina uma URL absoluta.';
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '$key inválido: use http ou https.';
    }

    if (mustUseHttps && uri.scheme != 'https') {
      return '$key inválido para produção: use https.';
    }

    if (rejectLocal && _isLocalHost(uri.host)) {
      return '$key inválido para produção: não use endereço local.';
    }

    return null;
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '10.0.2.2' ||
        normalized == '0.0.0.0';
  }
}
