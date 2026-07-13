import 'package:flutter/material.dart';

class TopIdentityBar extends StatelessWidget {
  const TopIdentityBar({
    super.key,
    required this.firstName,
    required this.avatarUrl,
    required this.profileInitials,
    required this.isResolvingAvatar,
    required this.onProfile,
    required this.onSignOut,
  });

  final String firstName;
  final String avatarUrl;
  final String profileInitials;
  final bool isResolvingAvatar;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'MyCash',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Olá, $firstName!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Bem-vindo de volta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          tooltip: 'Perfil',
          offset: const Offset(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (value) {
            if (value == 'profile') {
              onProfile();
            }
            if (value == 'signOut') {
              onSignOut();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'profile', child: Text('Configurações')),
            PopupMenuItem(value: 'signOut', child: Text('Sair')),
          ],
          child: _ProfileAvatar(
            avatarUrl: avatarUrl,
            profileInitials: profileInitials,
            isResolvingAvatar: isResolvingAvatar,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.profileInitials,
    required this.isResolvingAvatar,
  });

  final String avatarUrl;
  final String profileInitials;
  final bool isResolvingAvatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.secondary.withValues(alpha: 0.28),
            colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: colorScheme.secondary.withValues(alpha: 0.14),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: isResolvingAvatar
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.secondary,
                ),
              )
            : avatarUrl.isEmpty
            ? Text(
                profileInitials,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
    );
  }
}
