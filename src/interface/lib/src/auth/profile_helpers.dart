String? extractAvatarUrl(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return null;
  }

  final raw = metadata['avatar_url']?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  return raw;
}

String? extractAvatarPath(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return null;
  }

  final raw = metadata['avatar_path']?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  return raw;
}

String? extractAvatarVersion(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return null;
  }

  final raw = metadata['avatar_updated_at']?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  return raw;
}

String normalizeGoogleAvatarUrl(String? url) {
  final raw = (url ?? '').trim();
  if (raw.isEmpty) {
    return '';
  }

  if (!raw.contains('googleusercontent.com')) {
    return raw;
  }

  final sized = raw.replaceAll(RegExp(r's\d+-c'), 's256-c');
  if (sized != raw) {
    return sized;
  }

  if (sized.contains('=')) {
    return sized;
  }

  return '$sized=s256-c';
}

String buildAvatarCacheAwareUrl(String? url, String? version) {
  final rawUrl = (url ?? '').trim();
  if (rawUrl.isEmpty) {
    return '';
  }

  final versionValue = (version ?? '').trim();
  if (versionValue.isEmpty) {
    return rawUrl;
  }

  final separator = rawUrl.contains('?') ? '&' : '?';
  return '$rawUrl${separator}v=$versionValue';
}

String initialsFromProfile({required String fullName, required String email}) {
  final trimmedName = fullName.trim();
  if (trimmedName.isNotEmpty) {
    final parts = trimmedName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final firstTwo = parts.take(2).toList();
    if (firstTwo.isNotEmpty) {
      return firstTwo.map((part) => part[0].toUpperCase()).join();
    }
  }

  final trimmedEmail = email.trim();
  if (trimmedEmail.isNotEmpty) {
    return trimmedEmail[0].toUpperCase();
  }

  return 'U';
}
