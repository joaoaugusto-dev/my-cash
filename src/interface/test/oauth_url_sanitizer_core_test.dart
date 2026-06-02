import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/auth/oauth_url_sanitizer_core.dart';

void main() {
  test('removes sensitive OAuth params from query and fragment', () {
    final uri = Uri.parse(
      'https://app.example.com/?code=abc&state=xyz&safe=1'
      '#access_token=secret&refresh_token=refresh&view=home',
    );

    final sanitized = sanitizeOAuthUri(uri);

    expect(sanitized.toString(), 'https://app.example.com/?safe=1#view=home');
  });

  test('keeps non-OAuth route fragments intact', () {
    final uri = Uri.parse('https://app.example.com/#/transactions/details');

    expect(sanitizeOAuthUri(uri).toString(), uri.toString());
  });

  test('sanitizes query params inside route fragments', () {
    final uri = Uri.parse(
      'https://app.example.com/#/auth/callback?code=abc&tab=settings',
    );

    final sanitized = sanitizeOAuthUri(uri);

    expect(
      sanitized.toString(),
      'https://app.example.com/#/auth/callback?tab=settings',
    );
  });
}
