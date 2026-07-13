import 'package:flutter_test/flutter_test.dart';

import 'package:my_cash/src/config/app_env.dart';

void main() {
  test('AppEnv reports missing config when no --dart-define is provided', () {
    // ponytail: values come from --dart-define(-from-file) at build/run time;
    // plain `flutter test` has none set, so bootstrap validation must fail.
    expect(
      AppEnv.validateBootstrapConfig(),
      'Configuração ausente: SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL. '
      'Defina via --dart-define ou arquivo .env no build.',
    );
  });
}
