import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme_controller.dart';
import 'profile_helpers.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.themeController,
  });

  final Session session;
  final AppThemeController themeController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _avatarBucket = 'avatars';

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isResolvingAvatar = false;
  String? _avatarUrl;
  String? _avatarPath;
  String? _avatarVersion;
  String _resolvedAvatarUrl = '';
  String _avatarStateKey = '';
  late final Future<SharedPreferences> _preferencesFuture;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = SharedPreferences.getInstance();
    _syncUserData();
    _refreshResolvedAvatarUrl();
  }

  void _syncUserData() {
    final user =
        Supabase.instance.client.auth.currentUser ?? widget.session.user;
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final fullName = (metadata['full_name'] ?? metadata['name'] ?? '')
        .toString()
        .trim();

    _fullNameController.text = fullName;
    _emailController.text = user.email ?? '';
    _avatarUrl = extractAvatarUrl(metadata);
    _avatarPath = extractAvatarPath(metadata);
    _avatarVersion = extractAvatarVersion(metadata);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final selectedFile = result.files.single;
      final selectedBytes = selectedFile.bytes;
      if (selectedBytes == null || selectedBytes.isEmpty) {
        throw StateError('Não foi possível ler a imagem selecionada.');
      }

      setState(() {
        _isUploadingAvatar = true;
      });

      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      if (user == null) {
        throw StateError('Sessão expirada. Faça login novamente.');
      }

      final compressedBytes = await _compressAvatar(selectedBytes);
      final filePath = '${user.id}/avatar.jpg';
      final version = DateTime.now().toUtc().millisecondsSinceEpoch.toString();

      await Supabase.instance.client.storage
          .from(_avatarBucket)
          .uploadBinary(
            filePath,
            compressedBytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final currentMetadata = Map<String, dynamic>.from(
        user.userMetadata ?? const {},
      );
      currentMetadata['avatar_path'] = filePath;
      currentMetadata.remove('avatar_url');
      currentMetadata['avatar_source'] = 'upload';
      currentMetadata['avatar_updated_at'] = version;

      await auth.updateUser(UserAttributes(data: currentMetadata));

      final prefs = await _preferencesFuture;
      await clearCachedAvatarUrl(prefs: prefs, userId: user.id);

      if (mounted) {
        setState(() {
          _avatarPath = filePath;
          _avatarUrl = null;
          _avatarVersion = version;
        });
        await _refreshResolvedAvatarUrl();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao atualizar foto. Verifique se o bucket avatars existe no Supabase: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    try {
      setState(() {
        _isUploadingAvatar = true;
      });

      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;
      if (user == null) {
        throw StateError('Sessão expirada. Faça login novamente.');
      }

      if ((_avatarPath ?? '').isNotEmpty) {
        await Supabase.instance.client.storage.from(_avatarBucket).remove([
          _avatarPath!,
        ]);
      }

      final currentMetadata = Map<String, dynamic>.from(
        user.userMetadata ?? const {},
      );
      currentMetadata.remove('avatar_url');
      currentMetadata.remove('avatar_path');
      currentMetadata.remove('avatar_source');
      currentMetadata.remove('avatar_updated_at');

      await auth.updateUser(UserAttributes(data: currentMetadata));

      final prefs = await _preferencesFuture;
      await clearCachedAvatarUrl(prefs: prefs, userId: user.id);

      if (mounted) {
        setState(() {
          _avatarUrl = null;
          _avatarPath = null;
          _avatarVersion = null;
          _resolvedAvatarUrl = '';
          _avatarStateKey = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil removida.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao remover foto: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _saveAccountData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final user = auth.currentUser;

      if (user == null) {
        throw StateError('Sessão expirada. Faça login novamente.');
      }

      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final currentMetadata = Map<String, dynamic>.from(
        user.userMetadata ?? const {},
      );
      final currentAvatarUrl = extractAvatarUrl(currentMetadata);
      final currentAvatarPath = extractAvatarPath(currentMetadata);
      final currentAvatarVersion = extractAvatarVersion(currentMetadata);

      final currentFullName =
          ((user.userMetadata?['full_name'] ?? user.userMetadata?['name']) ??
                  '')
              .toString()
              .trim();
      final emailChanged = email != (user.email ?? '').trim();
      final nameChanged = fullName != currentFullName;
      final passwordChanged = password.isNotEmpty;
      final avatarChanged =
          _avatarUrl != currentAvatarUrl ||
          _avatarPath != currentAvatarPath ||
          _avatarVersion != currentAvatarVersion;

      if (!emailChanged && !nameChanged && !passwordChanged && !avatarChanged) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma alteração para salvar.')),
          );
        }
        return;
      }

      Map<String, dynamic>? updatedData;
      if (nameChanged || avatarChanged) {
        final metadata = currentMetadata;
        if (fullName.isEmpty) {
          metadata.remove('full_name');
        } else {
          metadata['full_name'] = fullName;
        }

        if ((_avatarUrl ?? '').trim().isEmpty) {
          metadata.remove('avatar_url');
        } else {
          metadata['avatar_url'] = _avatarUrl;
        }

        if ((_avatarPath ?? '').trim().isEmpty) {
          metadata.remove('avatar_path');
        } else {
          metadata['avatar_path'] = _avatarPath;
        }

        if ((_avatarVersion ?? '').trim().isEmpty) {
          metadata.remove('avatar_updated_at');
        } else {
          metadata['avatar_updated_at'] = _avatarVersion;
        }

        updatedData = metadata;
      }

      await auth.updateUser(
        UserAttributes(
          email: emailChanged ? email : null,
          password: passwordChanged ? password : null,
          data: updatedData,
        ),
      );

      _passwordController.clear();
      _syncUserData();
      await _refreshResolvedAvatarUrl();

      if (mounted) {
        final emailMessage = emailChanged
            ? ' Confira a caixa de entrada para confirmar o novo e-mail.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conta atualizada com sucesso.$emailMessage')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao atualizar conta: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  Future<void> _refreshResolvedAvatarUrl() async {
    final authUser =
        Supabase.instance.client.auth.currentUser ?? widget.session.user;
    final cacheIdentity = buildAvatarCacheIdentity(
      userId: authUser.id,
      avatarPath: _avatarPath,
      avatarUrl: _avatarUrl,
      avatarVersion: _avatarVersion,
    );
    final nextStateKey = cacheIdentity;
    if (nextStateKey == _avatarStateKey) {
      return;
    }

    _avatarStateKey = nextStateKey;
    setState(() {
      _isResolvingAvatar = true;
    });

    String resolvedUrl = '';

    try {
      final prefs = await _preferencesFuture;
      final cachedUrl = await readCachedAvatarUrl(
        prefs: prefs,
        userId: authUser.id,
        identity: cacheIdentity,
      );
      if (cachedUrl != null) {
        resolvedUrl = cachedUrl;
      } else if ((_avatarPath ?? '').isNotEmpty) {
        final signedUrl = await Supabase.instance.client.storage
            .from(_avatarBucket)
            .createSignedUrl(_avatarPath!, 60 * 60 * 24);
        resolvedUrl = buildAvatarCacheAwareUrl(signedUrl, _avatarVersion);
        await writeCachedAvatarUrl(
          prefs: prefs,
          userId: authUser.id,
          identity: cacheIdentity,
          avatarUrl: resolvedUrl,
          expiresAt: DateTime.now().toUtc().add(avatarSignedUrlCacheDuration),
        );
      } else {
        resolvedUrl = buildAvatarCacheAwareUrl(_avatarUrl, _avatarVersion);
        await writeCachedAvatarUrl(
          prefs: prefs,
          userId: authUser.id,
          identity: cacheIdentity,
          avatarUrl: resolvedUrl,
          expiresAt: DateTime.now().toUtc().add(avatarSignedUrlCacheDuration),
        );
      }
    } catch (_) {
      resolvedUrl = buildAvatarCacheAwareUrl(_avatarUrl, _avatarVersion);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _resolvedAvatarUrl = resolvedUrl;
      _isResolvingAvatar = false;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await widget.themeController.setThemeMode(mode);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = widget.themeController.themeMode;
    final profileInitials = initialsFromProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              colorScheme.secondary.withValues(alpha: isDark ? 0.16 : 0.09),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _SettingsSection(
              title: 'Perfil da conta',
              subtitle: 'Edite seus dados de acesso e identificação.',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: isDark ? 0.35 : 0.2,
                          ),
                          backgroundImage: _resolvedAvatarUrl.isNotEmpty
                              ? NetworkImage(_resolvedAvatarUrl)
                              : null,
                          child: _isResolvingAvatar
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _resolvedAvatarUrl.isEmpty
                              ? Text(
                                  profileInitials,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto de perfil',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Avatar 256x256 comprimido, salvo no Supabase Storage.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAvatar
                                ? null
                                : _pickAndUploadAvatar,
                            icon: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_back_rounded),
                            label: Text(
                              _isUploadingAvatar
                                  ? 'Enviando...'
                                  : 'Alterar foto',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed:
                              _isUploadingAvatar ||
                                  ((_avatarUrl ?? '').isEmpty &&
                                      (_avatarPath ?? '').isEmpty)
                              ? null
                              : _removeAvatar,
                          child: const Text('Remover'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nova senha (opcional)',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) {
                        final password = (value ?? '').trim();
                        if (password.isNotEmpty && password.length < 6) {
                          return 'A nova senha precisa ter ao menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveAccountData,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Salvando...' : 'Salvar alterações',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              title: 'Aparência',
              subtitle: 'Escolha o modo visual do aplicativo.',
              child: Column(
                children: [
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Claro'),
                        icon: Icon(Icons.wb_sunny_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Escuro'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('Sistema'),
                        icon: Icon(Icons.settings_suggest_rounded),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (selection) {
                      _setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      currentMode == ThemeMode.system
                          ? 'Modo atual: seguir configurações do sistema'
                          : currentMode == ThemeMode.dark
                          ? 'Modo atual: escuro'
                          : 'Modo atual: claro',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.72 : 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withValues(
              alpha: isDark ? 0.09 : 0.08,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
