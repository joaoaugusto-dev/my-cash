import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'package:my_cash/src/utils/oauth_url_sanitizer.dart';
import 'package:my_cash/src/config/app_env.dart';
import 'package:my_cash/src/ui/core/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await AppThemeController.create();
  final bootstrapError = await _bootstrapServices();
  runApp(
    MyApp(themeController: themeController, bootstrapError: bootstrapError),
  );
}

Future<String?> _bootstrapServices() async {
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
