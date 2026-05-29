import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});

  final Session session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _apiResponse;
  bool _isLoading = false;

  Future<void> _callProtectedApi() async {
    setState(() {
      _isLoading = true;
      _apiResponse = null;
    });

    try {
      final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/me');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      setState(() {
        _apiResponse = '${response.statusCode}: ${response.body}';
      });
    } catch (error) {
      setState(() {
        _apiResponse = 'Erro ao chamar API: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = widget.session.user.email ?? 'Conta autenticada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PJ-FINANC'),
        actions: [
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bem-vindo, $userEmail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Seu login por e-mail/senha ou Google já está ativo. A próxima etapa é consumir a API Nest com o JWT do Supabase.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _callProtectedApi,
                  child: const Text('Testar rota protegida do NestJS'),
                ),
                const SizedBox(height: 16),
                if (_apiResponse != null)
                  Text(
                    _apiResponse!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
