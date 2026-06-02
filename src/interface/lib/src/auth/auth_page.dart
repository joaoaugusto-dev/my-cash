import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';
import 'profile_helpers.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        await supabase.auth.signUp(email: email, password: password);
        _showMessage(
          'Cadastro enviado. Se o email confirmation estiver ativo no Supabase, confirme a conta no e-mail.',
        );
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Falha no login: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      if (kIsWeb) {
        await _signInWithGoogleOnWeb(supabase);
        return;
      }

      if (_shouldUseNativeGoogleSignIn) {
        final serverClientId = AppEnv.googleWebClientId;
        if (serverClientId.isEmpty) {
          throw StateError(
            'GOOGLE_WEB_CLIENT_ID não configurado para login nativo.',
          );
        }

        final googleSignIn = GoogleSignIn(serverClientId: serverClientId);
        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null || idToken.isEmpty) {
          throw StateError('Nenhum ID Token foi retornado pelo Google.');
        }

        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );

        await _syncGoogleAvatarIfNeeded(googleUser.photoUrl);
        return;
      }

      final launched = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null,
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        throw StateError(
          'Não foi possível abrir o fluxo de login Google no navegador.',
        );
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Falha ao iniciar Google login: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogleOnWeb(SupabaseClient supabase) async {
    final launched = await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _safeRedirectOrigin(),
      queryParams: const {'prompt': 'select_account'},
    );
    if (!launched) {
      throw StateError(
        'Não foi possível abrir o fluxo de login Google no navegador.',
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Informe seu e-mail para receber a recuperação de senha.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _safeRedirectOrigin(),
      );
      _showMessage('Enviamos as instruções de recuperação para o seu e-mail.');
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Falha ao solicitar recuperação: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _safeRedirectOrigin() {
    if (!kIsWeb) {
      return 'mycash://auth-callback';
    }

    final currentUri = Uri.base;
    if (currentUri.scheme != 'http' && currentUri.scheme != 'https') {
      throw StateError('Origem web inválida para OAuth: ${currentUri.scheme}.');
    }

    return currentUri.origin;
  }

  bool get _shouldUseNativeGoogleSignIn {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<void> _syncGoogleAvatarIfNeeded(String? googlePhotoUrl) async {
    final normalizedPhoto = normalizeGoogleAvatarUrl(googlePhotoUrl);
    if (normalizedPhoto.isEmpty) {
      return;
    }

    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    if (user == null) {
      return;
    }

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final customAvatarPath = extractAvatarPath(metadata);
    if (customAvatarPath != null) {
      return;
    }

    final currentAvatarUrl = extractAvatarUrl(metadata) ?? '';
    if (currentAvatarUrl == normalizedPhoto) {
      return;
    }

    metadata['avatar_url'] = normalizedPhoto;
    metadata['avatar_source'] = 'google';
    metadata['avatar_updated_at'] = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch
        .toString();

    try {
      await auth.updateUser(UserAttributes(data: metadata));
    } catch (_) {
      // Ignore sync failure here to keep login flow resilient.
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surface.withValues(
                    alpha: isDark ? 0.74 : 0.86,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: isDark ? 0.24 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MyCash',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Entre com e-mail/senha ou Google para acessar o controle financeiro.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Informe seu e-mail';
                              }
                              if (!email.contains('@')) {
                                return 'Informe um e-mail válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().length < 6) {
                                return 'A senha precisa ter pelo menos 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isLoading ? null : _submitEmailAuth,
                            child: Text(_isSignUp ? 'Criar conta' : 'Entrar'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata_outlined),
                            label: const Text('Continuar com Google'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                    });
                                  },
                            child: Text(
                              _isSignUp
                                  ? 'Já tenho conta. Fazer login'
                                  : 'Ainda não tenho conta. Criar cadastro',
                            ),
                          ),
                          if (!_isSignUp) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _isLoading ? null : _sendPasswordReset,
                              child: const Text('Esqueci minha senha'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
