import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/auth/oauth_url_sanitizer.dart';
import 'src/config/app_env.dart';
import 'src/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await AppThemeController.create();
  final bootstrapError = await _bootstrapServices();
  runApp(
    MyApp(themeController: themeController, bootstrapError: bootstrapError),
  );
}

Future<String?> _bootstrapServices() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional in production when using --dart-define.
  }

  final validationError = AppEnv.validateBootstrapConfig();
  if (validationError != null) {
    return validationError;
  }

  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    sanitizeOAuthUrl();
  } catch (error) {
    return 'Falha ao inicializar autenticação: $error';
  }

  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.themeController, this.bootstrapError});

  final AppThemeController themeController;
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return App(
      themeController: themeController,
      bootstrapError: bootstrapError,
    );
  }
}
