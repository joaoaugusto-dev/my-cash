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

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isResolvingAvatar = false;
  bool _isChangingTheme = false;
  ThemeMode? _pendingThemeMode;
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
      final nameChanged = fullName != currentFullName;
      final avatarChanged =
          _avatarUrl != currentAvatarUrl ||
          _avatarPath != currentAvatarPath ||
          _avatarVersion != currentAvatarVersion;

      if (!nameChanged && !avatarChanged) {
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

      await auth.updateUser(UserAttributes(data: updatedData));

      _syncUserData();
      await _refreshResolvedAvatarUrl();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso.')),
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
    if (_isChangingTheme || widget.themeController.themeMode == mode) {
      return;
    }

    setState(() {
      _isChangingTheme = true;
      _pendingThemeMode = mode;
    });

    try {
      await widget.themeController.setThemeMode(mode);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Aparência atualizada.')),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingTheme = false;
          _pendingThemeMode = null;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = widget.themeController.themeMode;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomOverlaySpacing =
        bottomInset + MediaQuery.paddingOf(context).bottom + 176;
    final profileInitials = initialsFromProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _SettingsBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 14, 20, bottomOverlaySpacing),
              children: [
                _SettingsTopBar(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 16),
                _SettingsAnimatedSection(
                  order: 0,
                  child: _SettingsSection(
                    title: 'Perfil da conta',
                    subtitle: 'Edite sua identificação e foto de perfil.',
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _emailController.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.58),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isCompact = constraints.maxWidth < 340;
                              final uploadButton = OutlinedButton.icon(
                                onPressed: _isUploadingAvatar
                                    ? null
                                    : _pickAndUploadAvatar,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: _isUploadingAvatar
                                      ? const SizedBox(
                                          key: ValueKey('uploading'),
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.photo_camera_back_rounded,
                                          key: ValueKey('camera'),
                                        ),
                                ),
                                label: Text(
                                  _isUploadingAvatar
                                      ? 'Enviando...'
                                      : 'Alterar foto',
                                ),
                              );
                              final removeButton = OutlinedButton(
                                onPressed:
                                    _isUploadingAvatar ||
                                        ((_avatarUrl ?? '').isEmpty &&
                                            (_avatarPath ?? '').isEmpty)
                                    ? null
                                    : _removeAvatar,
                                child: const Text('Remover'),
                              );

                              if (isCompact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    uploadButton,
                                    const SizedBox(height: 10),
                                    removeButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: uploadButton),
                                  const SizedBox(width: 10),
                                  removeButton,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.done,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              labelText: 'Nome completo',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _saveAccountData,
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _isSaving
                                    ? const SizedBox(
                                        key: ValueKey('saving'),
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.save_rounded,
                                        key: ValueKey('save'),
                                      ),
                              ),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  _isSaving
                                      ? 'Salvando...'
                                      : 'Salvar alterações',
                                  key: ValueKey(_isSaving),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsAnimatedSection(
                  order: 1,
                  child: _SettingsSection(
                    title: 'Aparência',
                    subtitle: 'Escolha o modo visual do aplicativo.',
                    child: Column(
                      children: [
                        _ThemeModeSelector(
                          currentMode: currentMode,
                          isChanging: _isChangingTheme,
                          pendingMode: _pendingThemeMode,
                          onChanged: _setThemeMode,
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: Container(
                            key: ValueKey(currentMode),
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isChangingTheme) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    currentMode == ThemeMode.system
                                        ? 'Modo atual: seguir configurações do sistema'
                                        : currentMode == ThemeMode.dark
                                        ? 'Modo atual: escuro'
                                        : 'Modo atual: claro',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsAnimatedSection(
                  order: 2,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        backgroundColor: colorScheme.surface.withValues(
                          alpha: isDark ? 0.7 : 0.84,
                        ),
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sair'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.72 : 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
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
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

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
            right: -80,
            child: _SettingsGlow(
              size: 260,
              color: const Color(
                0xFF8B2CEB,
              ).withValues(alpha: isDark ? 0.22 : 0.16),
            ),
          ),
          Positioned(
            top: 220,
            left: -120,
            child: _SettingsGlow(
              size: 300,
              color: const Color(
                0xFF22C55E,
              ).withValues(alpha: isDark ? 0.10 : 0.08),
            ),
          ),
          Positioned(
            bottom: -110,
            right: -60,
            child: _SettingsGlow(
              size: 260,
              color: const Color(
                0xFF5B9BFF,
              ).withValues(alpha: isDark ? 0.12 : 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGlow extends StatelessWidget {
  const _SettingsGlow({required this.size, required this.color});

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

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _RoundIconButton(
          tooltip: 'Voltar',
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Configurações',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsAnimatedSection extends StatefulWidget {
  const _SettingsAnimatedSection({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_SettingsAnimatedSection> createState() =>
      _SettingsAnimatedSectionState();
}

class _SettingsAnimatedSectionState extends State<_SettingsAnimatedSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.order * 80), () {
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
      offset: _visible ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
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
              color: colorScheme.outline.withValues(alpha: 0.52),
            ),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.currentMode,
    required this.isChanging,
    required this.pendingMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final bool isChanging;
  final ThemeMode? pendingMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      _ThemeModeOptionData(
        mode: ThemeMode.light,
        label: 'Claro',
        icon: Icons.wb_sunny_rounded,
      ),
      _ThemeModeOptionData(
        mode: ThemeMode.dark,
        label: 'Escuro',
        icon: Icons.dark_mode_rounded,
      ),
      _ThemeModeOptionData(
        mode: ThemeMode.system,
        label: 'Sistema',
        icon: Icons.settings_suggest_rounded,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          Expanded(
            child: _ThemeModeOption(
              data: options[index],
              selected: currentMode == options[index].mode,
              isChanging: isChanging && pendingMode == options[index].mode,
              onTap: isChanging ? null : () => onChanged(options[index].mode),
            ),
          ),
          if (index != options.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ThemeModeOptionData {
  const _ThemeModeOptionData({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.data,
    required this.selected,
    required this.isChanging,
    required this.onTap,
  });

  final _ThemeModeOptionData data;
  final bool selected;
  final bool isChanging;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF8B2CEB)],
                )
              : null,
          color: selected ? null : colorScheme.surface.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.18)
                : colorScheme.outline.withValues(alpha: 0.52),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 20,
              color: selected ? Colors.white : colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isChanging
                    ? const SizedBox(
                        key: ValueKey('loader'),
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FittedBox(
                        key: ValueKey(data.label),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.label,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
