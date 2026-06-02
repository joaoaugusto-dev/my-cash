const Set<String> sensitiveOAuthKeys = {
  'access_token',
  'code',
  'expires_at',
  'expires_in',
  'id_token',
  'provider_refresh_token',
  'provider_token',
  'refresh_token',
  'state',
  'token_type',
};

Uri sanitizeOAuthUri(Uri uri) {
  final sanitizedQuery = removeSensitiveOAuthParams(uri.queryParameters);
  final sanitizedFragment = sanitizeOAuthFragment(uri.fragment);

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery,
    fragment: sanitizedFragment.isEmpty ? null : sanitizedFragment,
  );
}

Map<String, String> removeSensitiveOAuthParams(Map<String, String> params) {
  final sanitized = <String, String>{};
  for (final entry in params.entries) {
    if (!sensitiveOAuthKeys.contains(entry.key)) {
      sanitized[entry.key] = entry.value;
    }
  }
  return sanitized;
}

String sanitizeOAuthFragment(String fragment) {
  if (fragment.isEmpty) {
    return fragment;
  }

  if (_looksLikeRawParams(fragment)) {
    final params = Uri.splitQueryString(fragment);
    final sanitized = removeSensitiveOAuthParams(params);
    if (sanitized.isEmpty) {
      return '';
    }
    return Uri(queryParameters: sanitized).query;
  }

  final queryStart = fragment.indexOf('?');
  if (queryStart < 0 || queryStart == fragment.length - 1) {
    return fragment;
  }

  final fragmentPath = fragment.substring(0, queryStart);
  final fragmentQuery = fragment.substring(queryStart + 1);
  if (!_looksLikeRawParams(fragmentQuery)) {
    return fragment;
  }

  final params = Uri.splitQueryString(fragmentQuery);
  final sanitized = removeSensitiveOAuthParams(params);
  if (sanitized.isEmpty) {
    return fragmentPath;
  }

  final rebuiltQuery = Uri(queryParameters: sanitized).query;
  return '$fragmentPath?$rebuiltQuery';
}

bool _looksLikeRawParams(String value) {
  return value.contains('=') && !value.contains('/');
}
