import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/auth/session_access_token_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'returns the current access token when the session is still valid',
    () async {
      final currentSession = _sessionExpiringIn(
        const Duration(minutes: 5),
        tokenLabel: 'valid-token',
      );
      final provider = SessionAccessTokenProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async =>
            throw UnimplementedError('refresh not expected'),
      );

      await expectLater(
        provider.call(),
        completion(currentSession.accessToken),
      );
    },
  );

  test(
    'refreshes an expired session before returning the access token',
    () async {
      Session? currentSession = _sessionExpiringIn(
        const Duration(seconds: -30),
        tokenLabel: 'expired-token',
      );
      Session? refreshedSession;

      final provider = SessionAccessTokenProvider(
        currentSessionProvider: () => currentSession,
        refreshSession: () async {
          refreshedSession = _sessionExpiringIn(
            const Duration(minutes: 5),
            tokenLabel: 'fresh-token',
          );
          currentSession = refreshedSession;
          return AuthResponse(session: currentSession);
        },
      );

      final token = await provider.call();

      expect(token, refreshedSession!.accessToken);
    },
  );

  test('shares the same refresh request across concurrent calls', () async {
    var refreshCalls = 0;
    Session? currentSession = _sessionExpiringIn(
      const Duration(seconds: -30),
      tokenLabel: 'expired-token',
    );

    final provider = SessionAccessTokenProvider(
      currentSessionProvider: () => currentSession,
      refreshSession: () async {
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        currentSession = _sessionExpiringIn(
          const Duration(minutes: 5),
          tokenLabel: 'fresh-token',
        );
        return AuthResponse(session: currentSession);
      },
    );

    final results = await Future.wait([provider.call(), provider.call()]);
    final refreshedToken = currentSession!.accessToken;

    expect(results, [refreshedToken, refreshedToken]);
    expect(refreshCalls, 1);
  });
}

Session _sessionExpiringIn(Duration offset, {required String tokenLabel}) {
  return Session(
    accessToken: _buildJwt(
      exp: DateTime.now().add(offset),
      tokenLabel: tokenLabel,
    ),
    refreshToken: 'refresh-$tokenLabel',
    tokenType: 'bearer',
    user: const User(
      id: 'user-1',
      appMetadata: {'provider': 'email'},
      userMetadata: {'name': 'Test User'},
      aud: 'authenticated',
      email: 'test@example.com',
      createdAt: '2026-01-01T00:00:00.000Z',
    ),
  );
}

String _buildJwt({required DateTime exp, required String tokenLabel}) {
  final header = _base64UrlEncode(<String, dynamic>{
    'alg': 'HS256',
    'typ': 'JWT',
  });
  final payload = _base64UrlEncode(<String, dynamic>{
    'exp': exp.millisecondsSinceEpoch ~/ 1000,
    'sub': 'user-1',
    'role': 'authenticated',
    'tag': tokenLabel,
  });
  return '$header.$payload.signature';
}

String _base64UrlEncode(Map<String, dynamic> jsonObject) {
  return base64Url
      .encode(utf8.encode(jsonEncode(jsonObject)))
      .replaceAll('=', '');
}
