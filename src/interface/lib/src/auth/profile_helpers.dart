import 'package:shared_preferences/shared_preferences.dart';

const Duration avatarSignedUrlCacheDuration = Duration(hours: 24);

String buildAvatarCacheIdentity({
  required String userId,
  String? avatarPath,
  String? avatarUrl,
  String? avatarVersion,
}) {
  return [
    userId.trim(),
    (avatarPath ?? '').trim(),
    (avatarUrl ?? '').trim(),
    (avatarVersion ?? '').trim(),
  ].join('|');
}

String _avatarCacheUrlKey(String userId) => 'avatar_cache_url_$userId';
String _avatarCacheIdentityKey(String userId) =>
    'avatar_cache_identity_$userId';
String _avatarCacheExpiresAtKey(String userId) =>
    'avatar_cache_expires_at_$userId';

String? _readCachedString(SharedPreferences prefs, String key) {
  final value = prefs.getString(key)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  return value;
}

Future<String?> readCachedAvatarUrl({
  required SharedPreferences prefs,
  required String userId,
  required String identity,
}) async {
  final cachedIdentity = _readCachedString(
    prefs,
    _avatarCacheIdentityKey(userId),
  );
  if (cachedIdentity != identity) {
    return null;
  }

  final expiresAtMillis = prefs.getInt(_avatarCacheExpiresAtKey(userId));
  if (expiresAtMillis == null) {
    return null;
  }

  final expiresAt = DateTime.fromMillisecondsSinceEpoch(
    expiresAtMillis,
    isUtc: true,
  );
  if (!DateTime.now().toUtc().isBefore(expiresAt)) {
    return null;
  }

  return _readCachedString(prefs, _avatarCacheUrlKey(userId));
}

Future<void> writeCachedAvatarUrl({
  required SharedPreferences prefs,
  required String userId,
  required String identity,
  required String avatarUrl,
  required DateTime expiresAt,
}) async {
  await prefs.setString(_avatarCacheIdentityKey(userId), identity);
  await prefs.setString(_avatarCacheUrlKey(userId), avatarUrl);
  await prefs.setInt(
    _avatarCacheExpiresAtKey(userId),
    expiresAt.toUtc().millisecondsSinceEpoch,
  );
}

Future<void> clearCachedAvatarUrl({
  required SharedPreferences prefs,
  required String userId,
}) async {
  await prefs.remove(_avatarCacheIdentityKey(userId));
  await prefs.remove(_avatarCacheUrlKey(userId));
  await prefs.remove(_avatarCacheExpiresAtKey(userId));
}

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
