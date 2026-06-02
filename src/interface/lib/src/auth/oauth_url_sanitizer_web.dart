// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'oauth_url_sanitizer_core.dart';

void sanitizeOAuthUrlImpl() {
  final uri = Uri.base;
  final sanitizedUri = sanitizeOAuthUri(uri);
  if (sanitizedUri.toString() == uri.toString()) {
    return;
  }

  html.window.history.replaceState(
    null,
    html.document.title,
    sanitizedUri.toString(),
  );
}
