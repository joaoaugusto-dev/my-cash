import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  static const String _avatarBucket = 'avatars';

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _signUpTokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Uint8List? _selectedAvatarBytes;
  Timer? _signUpResendTimer;
  int _signUpStep = 0;
  int _signUpResendSeconds = 0;
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _activeAuthAction;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _signUpTokenController.dispose();
    _signUpResendTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSignUp && _signUpStep == 0) {
      setState(() {
        _signUpStep = 1;
      });
      return;
    }

    if (_isSignUp && _signUpStep == 2) {
      await _verifySignUpToken();
      return;
    }

    setState(() {
      _isLoading = true;
      _activeAuthAction = 'email';
    });

    try {
      final supabase = Supabase.instance.client;
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _safeRedirectOrigin(),
          data: {if (fullName.isNotEmpty) 'full_name': fullName},
        );

        if (_signUpResponseLooksLikeExistingAccount(response)) {
          _showMessage(_existingAccountMessage);
          return;
        }

        if (Supabase.instance.client.auth.currentSession != null) {
          await Supabase.instance.client.auth.signOut();
        }
        if (!mounted) {
          return;
        }
        _signUpTokenController.clear();
        _startSignUpResendTimer();
        setState(() {
          _signUpStep = 2;
        });
        _showMessage(
          'Enviamos o código de confirmação de 6 dígitos para seu e-mail.',
        );
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha no login: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAuthAction = null;
        });
      }
    }
  }

  Future<void> _verifySignUpToken() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _activeAuthAction = 'email';
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _signUpTokenController.text.trim(),
        type: OtpType.signup,
      );
      await _uploadSelectedAvatarIfPossible(
        fullName: _fullNameController.text.trim(),
      );
      _showMessage('Cadastro confirmado com sucesso.');
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha ao confirmar cadastro: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAuthAction = null;
        });
      }
    }
  }

  Future<void> _resendSignUpToken() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Informe um e-mail válido para reenviar o código.');
      return;
    }

    setState(() {
      _isLoading = true;
      _activeAuthAction = 'resend-signup';
    });

    try {
      await Supabase.instance.client.auth.resend(
        email: email,
        type: OtpType.signup,
        emailRedirectTo: _safeRedirectOrigin(),
      );
      _startSignUpResendTimer();
      _showMessage('Código reenviado para seu e-mail.');
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha ao reenviar código: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAuthAction = null;
        });
      }
    }
  }

  void _startSignUpResendTimer() {
    _signUpResendTimer?.cancel();
    setState(() {
      _signUpResendSeconds = 30;
    });
    _signUpResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_signUpResendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _signUpResendSeconds = 0;
        });
        return;
      }
      setState(() {
        _signUpResendSeconds--;
      });
    });
  }

  void _goBackSignUpStep() {
    if (_signUpStep <= 0) {
      setState(() {
        _isSignUp = false;
      });
      return;
    }

    setState(() {
      _signUpStep--;
    });
  }

  Future<void> _pickSignUpAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Não foi possível ler a imagem selecionada.');
      }

      final compressed = await _compressAvatar(bytes);
      setState(() {
        _selectedAvatarBytes = compressed;
      });
    } catch (error) {
      _showMessage('Falha ao selecionar foto: $error');
    }
  }

  void _removeSignUpAvatar() {
    setState(() {
      _selectedAvatarBytes = null;
    });
  }

  Future<Uint8List> _compressAvatar(Uint8List sourceBytes) async {
    final compressedBytes = await FlutterImageCompress.compressWithList(
      sourceBytes,
      minWidth: 256,
      minHeight: 256,
      quality: 72,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes.isEmpty) {
      return sourceBytes;
    }

    return Uint8List.fromList(compressedBytes);
  }

  Future<void> _uploadSelectedAvatarIfPossible({
    required String fullName,
  }) async {
    final selectedAvatarBytes = _selectedAvatarBytes;
    if (selectedAvatarBytes == null) {
      return;
    }

    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    if (user == null) {
      return;
    }

    final filePath = '${user.id}/avatar.jpg';
    final version = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    await Supabase.instance.client.storage
        .from(_avatarBucket)
        .uploadBinary(
          filePath,
          selectedAvatarBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    if (fullName.isNotEmpty) {
      metadata['full_name'] = fullName;
    }
    metadata['avatar_path'] = filePath;
    metadata.remove('avatar_url');
    metadata['avatar_source'] = 'upload';
    metadata['avatar_updated_at'] = version;

    await auth.updateUser(UserAttributes(data: metadata));
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _activeAuthAction = 'google';
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
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha ao iniciar Google login: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAuthAction = null;
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

  Future<void> _openForgotPasswordPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ForgotPasswordPage(
          initialEmail: _emailController.text.trim(),
          redirectTo: _safeRedirectOrigin(),
        ),
      ),
    );
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _AuthAnimatedSection(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(
                              alpha: isDark ? 0.72 : 0.84,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.52,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.24 : 0.08,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    if (_isSignUp) ...[
                                      _AuthBackButton(
                                        onPressed: _goBackSignUpStep,
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: _AuthHeader(isSignUp: _isSignUp),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Text(
                                    _isSignUp
                                        ? 'Crie sua conta para organizar entradas, saídas e cartões em um só lugar.'
                                        : 'Entre para continuar acompanhando seu painel financeiro.',
                                    key: ValueKey(_isSignUp),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.64),
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: _isSignUp
                                      ? _SignUpStepFields(
                                          key: ValueKey(_signUpStep),
                                          step: _signUpStep,
                                          fullNameController:
                                              _fullNameController,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          confirmPasswordController:
                                              _confirmPasswordController,
                                          tokenController:
                                              _signUpTokenController,
                                          avatarBytes: _selectedAvatarBytes,
                                          obscurePassword: _obscurePassword,
                                          obscureConfirmPassword:
                                              _obscureConfirmPassword,
                                          isLoading: _isLoading,
                                          onPickAvatar: _pickSignUpAvatar,
                                          onRemoveAvatar: _removeSignUpAvatar,
                                          onProfileChanged: () =>
                                              setState(() {}),
                                          onPasswordChanged: (_) =>
                                              setState(() {}),
                                          onPasswordVisibility: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          onConfirmVisibility: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                          onTokenCompleted: () {
                                            if (!_isLoading) {
                                              _verifySignUpToken();
                                            }
                                          },
                                          onSubmit: () {
                                            if (!_isLoading) {
                                              _submitEmailAuth();
                                            }
                                          },
                                        )
                                      : _LoginFields(
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          obscurePassword: _obscurePassword,
                                          isLoading: _isLoading,
                                          onPasswordVisibility: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          onSubmit: _submitEmailAuth,
                                        ),
                                ),
                                const SizedBox(height: 22),
                                _LoadingFilledButton(
                                  isLoading:
                                      _activeAuthAction == 'email' &&
                                      _isLoading,
                                  onPressed: _isLoading
                                      ? null
                                      : _submitEmailAuth,
                                  icon: _isSignUp
                                      ? _signUpStep == 2
                                            ? Icons.mark_email_read_rounded
                                            : Icons.person_add_alt_rounded
                                      : Icons.login_rounded,
                                  label: _isSignUp
                                      ? _signUpStep == 0
                                            ? 'Continuar'
                                            : _signUpStep == 1
                                            ? 'Criar conta e enviar código'
                                            : 'Confirmar código'
                                      : 'Entrar',
                                ),
                                if (_isSignUp && _signUpStep == 2) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed:
                                        _isLoading || _signUpResendSeconds > 0
                                        ? null
                                        : _resendSignUpToken,
                                    child: Text(
                                      _signUpResendSeconds > 0
                                          ? 'Reenviar em ${_signUpResendSeconds}s'
                                          : 'Reenviar código',
                                    ),
                                  ),
                                ],
                                if (!_isSignUp) ...[
                                  const SizedBox(height: 12),
                                  _LoadingOutlinedButton(
                                    isLoading:
                                        _activeAuthAction == 'google' &&
                                        _isLoading,
                                    onPressed: _isLoading
                                        ? null
                                        : _signInWithGoogle,
                                    icon: ClipOval(
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(4),
                                        child: Image.asset(
                                          'assets/google_logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    label: 'Continuar com Google',
                                  ),
                                ],
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  child: _isSignUp && _signUpStep > 0
                                      ? SizedBox.shrink(
                                          key: ValueKey(
                                            'toggle-$_isSignUp-$_signUpStep',
                                          ),
                                        )
                                      : TextButton(
                                          key: ValueKey(
                                            'toggle-$_isSignUp-$_signUpStep',
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _isSignUp = !_isSignUp;
                                                    if (!_isSignUp) {
                                                      _signUpStep = 0;
                                                    }
                                                  });
                                                },
                                          child: Text(
                                            _isSignUp
                                                ? 'Já tenho conta. Fazer login'
                                                : 'Ainda não tenho conta. Criar cadastro',
                                          ),
                                        ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  child: _isSignUp
                                      ? const SizedBox.shrink()
                                      : Column(
                                          children: [
                                            const SizedBox(height: 4),
                                            TextButton.icon(
                                              onPressed: _isLoading
                                                  ? null
                                                  : _openForgotPasswordPage,
                                              icon: const Icon(
                                                Icons.key_rounded,
                                              ),
                                              label: const Text(
                                                'Esqueci minha senha',
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
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
          ),
        ],
      ),
    );
  }
}

String? _strongPasswordError(String password) {
  if (password.length < 12) {
    return 'Use no mínimo 12 caracteres';
  }
  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Inclua pelo menos uma letra maiúscula';
  }
  if (!password.contains(RegExp(r'[0-9]'))) {
    return 'Inclua pelo menos um número';
  }
  final hasSpecial = password.runes.any((rune) {
    final char = String.fromCharCode(rune);
    return !RegExp(r'[A-Za-z0-9]').hasMatch(char);
  });
  if (!hasSpecial) {
    return 'Inclua pelo menos um caractere especial';
  }
  return null;
}

const _existingAccountMessage =
    'Este e-mail já está cadastrado. Faça login ou use "Esqueci minha senha".';

bool _signUpResponseLooksLikeExistingAccount(AuthResponse response) {
  final identities = response.user?.identities;
  return response.session == null && identities != null && identities.isEmpty;
}

String _friendlyAuthMessage(AuthException error) {
  final code = error.code;
  final message = error.message;
  final normalizedMessage = message.toLowerCase();

  if (code == 'email_exists' ||
      code == 'user_already_exists' ||
      code == 'identity_already_exists' ||
      normalizedMessage.contains('already registered') ||
      normalizedMessage.contains('already exists') ||
      normalizedMessage.contains('email exists')) {
    return _existingAccountMessage;
  }

  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      normalizedMessage.contains('rate limit') ||
      normalizedMessage.contains('security purposes')) {
    return 'Muitas tentativas em sequência. Aguarde um pouco antes de tentar novamente.';
  }

  if (code == 'signup_disabled') {
    return 'O cadastro está temporariamente desativado.';
  }

  if (code == 'email_provider_disabled') {
    return 'Cadastro por e-mail está desativado no Supabase Auth.';
  }

  if (code == 'weak_password') {
    return 'A senha ainda não atende aos requisitos de segurança.';
  }

  if (code == 'otp_expired') {
    return 'Código expirado ou inválido. Peça um novo código e tente novamente.';
  }

  return message;
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.initialEmail,
    required this.redirectTo,
  });

  final String initialEmail;
  final String redirectTo;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordUpdated = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    if (_step == 2 && !_passwordUpdated) {
      Supabase.instance.client.auth.signOut();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      if (_step == 0) {
        _formKey.currentState?.validate();
      } else {
        _showMessage('Informe um e-mail válido para reenviar o token.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: widget.redirectTo,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 1;
      });
      _startResendTimer();
      _showMessage('Enviamos o token de recuperação para o seu e-mail.');
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
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

  bool _isValidEmail(String email) {
    return email.isNotEmpty && email.contains('@');
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 30;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendSeconds = 0;
        });
        return;
      }
      setState(() {
        _resendSeconds--;
      });
    });
  }

  void _goBackStep() {
    if (_step <= 0) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _step--;
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
        type: OtpType.recovery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 2;
      });
      _showMessage('Token validado. Agora defina sua nova senha.');
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha ao validar token: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      if (!mounted) {
        return;
      }
      _passwordUpdated = true;
      _showMessage('Senha atualizada com sucesso.');
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      _showMessage(_friendlyAuthMessage(error));
    } catch (error) {
      _showMessage('Falha ao atualizar senha: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _AuthAnimatedSection(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(
                              alpha: isDark ? 0.72 : 0.84,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: colorScheme.outline.withValues(
                                alpha: 0.52,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.24 : 0.08,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    _AuthBackButton(onPressed: _goBackStep),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Recuperar senha',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _step == 0
                                      ? 'Informe seu e-mail para receber o token de 6 dígitos do Supabase Auth.'
                                      : _step == 1
                                      ? 'Confira o endereço digitado e informe o token recebido para liberar uma nova senha.'
                                      : 'Token validado. Agora escolha uma senha forte.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.64,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                ),
                                const SizedBox(height: 22),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: _ForgotPasswordStep(
                                    key: ValueKey(_step),
                                    step: _step,
                                    emailController: _emailController,
                                    tokenController: _tokenController,
                                    passwordController: _passwordController,
                                    confirmPasswordController:
                                        _confirmPasswordController,
                                    obscurePassword: _obscurePassword,
                                    obscureConfirmPassword:
                                        _obscureConfirmPassword,
                                    isLoading: _isLoading,
                                    onPasswordVisibility: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    onConfirmVisibility: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    onPasswordChanged: (_) => setState(() {}),
                                    onTokenCompleted: () {
                                      if (!_isLoading) {
                                        _verifyCode();
                                      }
                                    },
                                    onSubmit: () {
                                      if (!_isLoading) {
                                        if (_step == 0)
                                          _sendCode();
                                        else if (_step == 2)
                                          _updatePassword();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _LoadingFilledButton(
                                  isLoading: _isLoading,
                                  onPressed: _isLoading
                                      ? null
                                      : _step == 0
                                      ? _sendCode
                                      : _step == 1
                                      ? _verifyCode
                                      : _updatePassword,
                                  icon: _step == 0
                                      ? Icons.mark_email_read_rounded
                                      : _step == 1
                                      ? Icons.password_rounded
                                      : Icons.lock_reset_rounded,
                                  label: _step == 0
                                      ? 'Enviar token'
                                      : _step == 1
                                      ? 'Validar token'
                                      : 'Salvar nova senha',
                                ),
                                if (_step == 1) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: _isLoading || _resendSeconds > 0
                                        ? null
                                        : _sendCode,
                                    child: Text(
                                      _resendSeconds > 0
                                          ? 'Reenviar em ${_resendSeconds}s'
                                          : 'Reenviar token',
                                    ),
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
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordStep extends StatelessWidget {
  const _ForgotPasswordStep({
    super.key,
    required this.step,
    required this.emailController,
    required this.tokenController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isLoading,
    required this.onPasswordVisibility,
    required this.onConfirmVisibility,
    required this.onPasswordChanged,
    required this.onTokenCompleted,
    required this.onSubmit,
  });

  final int step;
  final TextEditingController emailController;
  final TextEditingController tokenController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isLoading;
  final VoidCallback onPasswordVisibility;
  final VoidCallback onConfirmVisibility;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTokenCompleted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return TextFormField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => onSubmit(),
        enabled: !isLoading,
        decoration: const InputDecoration(
          labelText: 'E-mail',
          prefixIcon: Icon(Icons.alternate_email_rounded),
        ),
        validator: (value) {
          final email = (value ?? '').trim();
          if (email.isEmpty) {
            return 'Informe seu e-mail';
          }
          if (!email.contains('@')) {
            return 'Informe um e-mail válido';
          }
          return null;
        },
      );
    }

    if (step == 1) {
      return _OtpVerificationPanel(
        email: emailController.text.trim(),
        title: 'Token de 6 dígitos',
        semanticLabel: 'Token de recuperação de 6 dígitos',
        controller: tokenController,
        enabled: !isLoading,
        helperText:
            'Se houver uma conta vinculada a este e-mail, o token chegará em alguns instantes.',
        onCompleted: onTokenCompleted,
        validator: (value) {
          if (!RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())) {
            return 'Informe o token de 6 dígitos';
          }
          return null;
        },
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          enabled: !isLoading,
          onChanged: onPasswordChanged,
          decoration: InputDecoration(
            labelText: 'Nova senha',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: isLoading ? null : onPasswordVisibility,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => _strongPasswordError((value ?? '').trim()),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          enabled: !isLoading,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Confirmar nova senha',
            prefixIcon: const Icon(Icons.verified_user_rounded),
            suffixIcon: IconButton(
              onPressed: isLoading ? null : onConfirmVisibility,
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) {
            if ((value ?? '').trim() != passwordController.text.trim()) {
              return 'As senhas precisam ser iguais';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _PasswordRules(password: passwordController.text),
      ],
    );
  }
}

class _LoginFields extends StatelessWidget {
  const _LoginFields({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onPasswordVisibility,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onPasswordVisibility;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !isLoading,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.alternate_email_rounded),
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
        const SizedBox(height: 14),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          enabled: !isLoading,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: 'Senha',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: isLoading ? null : onPasswordVisibility,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  key: ValueKey(obscurePassword),
                ),
              ),
            ),
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Informe sua senha';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _SignUpStepFields extends StatelessWidget {
  const _SignUpStepFields({
    super.key,
    required this.step,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.tokenController,
    required this.avatarBytes,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isLoading,
    required this.onPickAvatar,
    required this.onRemoveAvatar,
    required this.onProfileChanged,
    required this.onPasswordChanged,
    required this.onPasswordVisibility,
    required this.onConfirmVisibility,
    required this.onTokenCompleted,
    required this.onSubmit,
  });

  final int step;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController tokenController;
  final Uint8List? avatarBytes;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isLoading;
  final VoidCallback onPickAvatar;
  final VoidCallback onRemoveAvatar;
  final VoidCallback onProfileChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onPasswordVisibility;
  final VoidCallback onConfirmVisibility;
  final VoidCallback onTokenCompleted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return Column(
        children: [
          _SignUpAvatarHero(
            fullName: fullNameController.text,
            email: emailController.text,
            avatarBytes: avatarBytes,
            onPick: isLoading ? null : onPickAvatar,
            onRemove: avatarBytes == null || isLoading ? null : onRemoveAvatar,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: fullNameController,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            onChanged: (_) => onProfileChanged(),
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Informe seu nome';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            enabled: !isLoading,
            onChanged: (_) => onProfileChanged(),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.alternate_email_rounded),
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
        ],
      );
    }

    if (step == 1) {
      return Column(
        children: [
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            enabled: !isLoading,
            onChanged: onPasswordChanged,
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: isLoading ? null : onPasswordVisibility,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => _strongPasswordError((value ?? '').trim()),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            enabled: !isLoading,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Confirmar senha',
              prefixIcon: const Icon(Icons.verified_user_rounded),
              suffixIcon: IconButton(
                onPressed: isLoading ? null : onConfirmVisibility,
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if ((value ?? '').trim() != passwordController.text.trim()) {
                return 'As senhas precisam ser iguais';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _CompactPasswordRules(password: passwordController.text),
        ],
      );
    }

    return _OtpVerificationPanel(
      email: emailController.text.trim(),
      title: 'Código de confirmação',
      semanticLabel: 'Código de confirmação de cadastro de 6 dígitos',
      controller: tokenController,
      enabled: !isLoading,
      helperText:
          'O código confirma que este e-mail pertence a você antes de liberar o acesso ao app.',
      onCompleted: onTokenCompleted,
      validator: (value) {
        if (!RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())) {
          return 'Informe o código de 6 dígitos';
        }
        return null;
      },
    );
  }
}

class _SignUpAvatarHero extends StatelessWidget {
  const _SignUpAvatarHero({
    required this.fullName,
    required this.email,
    required this.avatarBytes,
    required this.onPick,
    required this.onRemove,
  });

  final String fullName;
  final String email;
  final Uint8List? avatarBytes;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = initialsFromProfile(fullName: fullName, email: email);
    final avatar = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey('${avatarBytes?.length ?? 0}-$initials'),
        width: 74,
        height: 74,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              colorScheme.secondary.withValues(alpha: 0.34),
              colorScheme.primary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          backgroundImage: avatarBytes == null
              ? null
              : MemoryImage(avatarBytes!),
          child: avatarBytes == null
              ? Text(
                  initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto do perfil',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          avatarBytes == null
              ? 'Opcional. Sem foto, usamos suas iniciais automaticamente.'
              : 'Foto selecionada. Você pode trocar ou remover.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.62),
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_camera_back_rounded),
              label: Text(avatarBytes == null ? 'Adicionar' : 'Trocar'),
            ),
            if (avatarBytes != null)
              TextButton(onPressed: onRemove, child: const Text('Remover')),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.48)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: avatar),
                const SizedBox(height: 14),
                copy,
              ],
            );
          }

          return Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _OtpVerificationPanel extends StatelessWidget {
  const _OtpVerificationPanel({
    required this.email,
    required this.title,
    required this.semanticLabel,
    required this.controller,
    required this.enabled,
    required this.helperText,
    required this.onCompleted,
    required this.validator,
  });

  final String email;
  final String title;
  final String semanticLabel;
  final TextEditingController controller;
  final bool enabled;
  final String helperText;
  final VoidCallback onCompleted;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeEmail = email.isEmpty ? 'seu e-mail' : email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifique o e-mail $safeEmail',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$helperText Confira também a caixa de spam, promoções ou lixo eletrônico.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OtpCodeInput(
          controller: controller,
          enabled: enabled,
          title: title,
          semanticLabel: semanticLabel,
          onCompleted: onCompleted,
          validator: validator,
        ),
      ],
    );
  }
}

class _OtpCodeInput extends StatefulWidget {
  const _OtpCodeInput({
    required this.controller,
    required this.enabled,
    required this.title,
    required this.semanticLabel,
    required this.onCompleted,
    required this.validator,
  });

  final TextEditingController controller;
  final bool enabled;
  final String title;
  final String semanticLabel;
  final VoidCallback onCompleted;
  final FormFieldValidator<String> validator;

  @override
  State<_OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<_OtpCodeInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    _focusNode.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    _focusNode.removeListener(_handleChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    setState(() {});
  }

  void _focus() {
    if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final code = widget.controller.text;

    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => widget.validator(widget.controller.text),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              textField: true,
              label: widget.semanticLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focus,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var index = 0; index < 6; index++) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(
                                  alpha: widget.enabled ? 0.74 : 0.38,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _focusNode.hasFocus
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.72,
                                        )
                                      : colorScheme.outline.withValues(
                                          alpha: 0.58,
                                        ),
                                  width: _focusNode.hasFocus ? 1.4 : 1,
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                child: Text(
                                  index < code.length ? code[index] : '',
                                  key: ValueKey(
                                    index < code.length ? code[index] : '_',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          if (index != 5) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.01,
                        child: TextFormField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          showCursor: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            field.didChange(value);
                            if (value.length == 6) {
                              FocusScope.of(context).unfocus();
                              widget.onCompleted();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 8),
              Text(
                field.errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 12;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.runes.any((rune) {
      final char = String.fromCharCode(rune);
      return !RegExp(r'[A-Za-z0-9]').hasMatch(char);
    });

    return Column(
      children: [
        _PasswordRuleRow(
          label: 'Mínimo de 12 caracteres',
          isValid: hasMinLength,
        ),
        const SizedBox(height: 6),
        _PasswordRuleRow(
          label: 'Pelo menos uma letra maiúscula',
          isValid: hasUppercase,
        ),
        const SizedBox(height: 6),
        _PasswordRuleRow(label: 'Pelo menos um número', isValid: hasNumber),
        const SizedBox(height: 6),
        _PasswordRuleRow(
          label: 'Pelo menos um caractere especial',
          isValid: hasSpecial,
        ),
      ],
    );
  }
}

class _CompactPasswordRules extends StatelessWidget {
  const _CompactPasswordRules({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('12+', password.length >= 12),
      ('A-Z', password.contains(RegExp(r'[A-Z]'))),
      ('0-9', password.contains(RegExp(r'[0-9]'))),
      (
        '#',
        password.runes.any((rune) {
          final char = String.fromCharCode(rune);
          return !RegExp(r'[A-Za-z0-9]').hasMatch(char);
        }),
      ),
    ];
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final (label, isValid) in rules)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (isValid ? colorScheme.tertiary : colorScheme.onSurface)
                  .withValues(alpha: isValid ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isValid ? Icons.check_rounded : Icons.circle_outlined,
                  size: 14,
                  color:
                      (isValid ? colorScheme.tertiary : colorScheme.onSurface)
                          .withValues(alpha: isValid ? 1 : 0.5),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        (isValid ? colorScheme.tertiary : colorScheme.onSurface)
                            .withValues(alpha: isValid ? 1 : 0.62),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PasswordRuleRow extends StatelessWidget {
  const _PasswordRuleRow({required this.label, required this.isValid});

  final String label;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isValid ? colorScheme.tertiary : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isValid ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isValid ? Icons.check_circle_rounded : Icons.circle_outlined,
              key: ValueKey(isValid),
              size: 18,
              color: color.withValues(alpha: isValid ? 1 : 0.42),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: isValid ? 1 : 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Voltar',
      child: Semantics(
        button: true,
        label: 'Voltar',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(Icons.arrow_back_rounded, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF110A22), Color(0xFF1B1230), Color(0xFF0D0B16)]
              : const [Color(0xFFFBFAFF), Color(0xFFF4F0FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: _AuthGlow(
              size: 280,
              color: const Color(
                0xFF7C3AED,
              ).withValues(alpha: isDark ? 0.24 : 0.16),
            ),
          ),
          Positioned(
            top: 180,
            right: -120,
            child: _AuthGlow(
              size: 300,
              color: const Color(
                0xFFB993FF,
              ).withValues(alpha: isDark ? 0.16 : 0.22),
            ),
          ),
          Positioned(
            bottom: -140,
            left: 20,
            child: _AuthGlow(
              size: 300,
              color: const Color(
                0xFF22C55E,
              ).withValues(alpha: isDark ? 0.10 : 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _AuthAnimatedSection extends StatefulWidget {
  const _AuthAnimatedSection({required this.child});

  final Widget child;

  @override
  State<_AuthAnimatedSection> createState() => _AuthAnimatedSectionState();
}

class _AuthAnimatedSectionState extends State<_AuthAnimatedSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.05),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MyCash',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  isSignUp ? 'Criar cadastro' : 'Bem-vindo de volta',
                  key: ValueKey(isSignUp),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingFilledButton extends StatelessWidget {
  const _LoadingFilledButton({
    required this.isLoading,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isLoading ? 0.985 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, key: const ValueKey('icon')),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            isLoading ? 'Processando...' : label,
            key: ValueKey(isLoading ? 'loading' : label),
          ),
        ),
      ),
    );
  }
}

class _LoadingOutlinedButton extends StatelessWidget {
  const _LoadingOutlinedButton({
    required this.isLoading,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isLoading ? 0.985 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : KeyedSubtree(key: const ValueKey('icon'), child: icon),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            isLoading ? 'Abrindo...' : label,
            key: ValueKey(isLoading ? 'loading' : label),
          ),
        ),
      ),
    );
  }
}
