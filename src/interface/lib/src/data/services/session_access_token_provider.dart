import 'package:supabase_flutter/supabase_flutter.dart';

class SessionAccessTokenProvider {
  SessionAccessTokenProvider({
    required Session? Function() currentSessionProvider,
    required Future<AuthResponse> Function() refreshSession,
  }) : _currentSessionProvider = currentSessionProvider,
       _refreshSession = refreshSession;

  final Session? Function() _currentSessionProvider;
  final Future<AuthResponse> Function() _refreshSession;

  Future<Session>? _refreshInFlight;

  Future<String> call() async {
    final session = _currentSessionProvider();
    if (session == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    if (!session.isExpired) {
      return session.accessToken;
    }

    final refreshedSession = await _refreshIfNeeded();
    return refreshedSession.accessToken;
  }

  Future<Session> _refreshIfNeeded() {
    final currentRefresh = _refreshInFlight;
    if (currentRefresh != null) {
      return currentRefresh;
    }

    final refreshFuture = _refreshCurrentSession();
    _refreshInFlight = refreshFuture;
    return refreshFuture;
  }

  Future<Session> _refreshCurrentSession() async {
    try {
      final response = await _refreshSession();
      final session = response.session ?? _currentSessionProvider();
      if (session == null) {
        throw StateError('Sessão expirada. Faça login novamente.');
      }

      return session;
    } finally {
      _refreshInFlight = null;
    }
  }
}
