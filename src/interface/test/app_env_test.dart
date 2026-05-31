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

    expect(AppEnv.supabaseUrl, 'https://example.supabase.co');
    expect(AppEnv.supabaseAnonKey, 'anon-key');
    expect(AppEnv.apiBaseUrl, 'http://localhost:3000');
    expect(
      AppEnv.googleWebClientId,
      'web-client-id.apps.googleusercontent.com',
    );
    expect(AppEnv.oauthRedirectScheme, 'mycash');
    expect(AppEnv.oauthRedirectHost, 'auth-callback');
  });
}