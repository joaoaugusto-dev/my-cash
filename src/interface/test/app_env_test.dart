import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_cash/src/config/app_env.dart';

void main() {
  test('AppEnv reads required values from dotenv', () {
    dotenv.testLoad(
      fileInput: '''
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
API_BASE_URL=http://localhost:3000
GOOGLE_WEB_CLIENT_ID=web-client-id.apps.googleusercontent.com
''',
    );

    expect(AppEnv.appEnvironment, 'development');
    expect(AppEnv.supabaseUrl, 'https://example.supabase.co');
    expect(AppEnv.supabaseAnonKey, 'anon-key');
    expect(AppEnv.apiBaseUrl, 'http://localhost:3000');
    expect(
      AppEnv.googleWebClientId,
      'web-client-id.apps.googleusercontent.com',
    );
    expect(AppEnv.validateBootstrapConfig(), isNull);
  });

  test('AppEnv rejects local or insecure urls in production', () {
    dotenv.testLoad(
      fileInput: '''
APP_ENV=production
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
API_BASE_URL=http://10.0.2.2:3000/api
GOOGLE_WEB_CLIENT_ID=web-client-id.apps.googleusercontent.com
''',
    );

    expect(
      AppEnv.validateBootstrapConfig(),
      'API_BASE_URL inválido para produção: use https.',
    );
  });

  test('AppEnv accepts https production urls', () {
    dotenv.testLoad(
      fileInput: '''
APP_ENV=production
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
API_BASE_URL=https://api.example.com/api
GOOGLE_WEB_CLIENT_ID=web-client-id.apps.googleusercontent.com
''',
    );

    expect(AppEnv.validateBootstrapConfig(), isNull);
  });
}
