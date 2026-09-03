import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  ChatApiService({
    required this.apiBaseUrl,
    required this.accessTokenProvider,
    http.Client? client,
    this.retryDelay = const Duration(minutes: 1),
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final FutureOr<String> Function() accessTokenProvider;
  final http.Client _client;

  /// How long to wait between retries when the AI provider reports high
  /// demand. Overridable in tests so they don't sit through a real minute.
  final Duration retryDelay;

  /// Retries attempted before giving up and surfacing the failure.
  static const maxRetries = 4;

  /// [messages] is the full conversation so far, oldest first, each entry
  /// shaped as {'role': 'user'|'assistant', 'content': ...}. `content` is a
  /// plain string, or a list of parts (text/image_url/input_audio) when the
  /// user attached a photo or voice note.
  ///
  /// The backend streams the reply as it's generated (running any tool calls
  /// against the user's own data along the way) and writes plain UTF-8 text
  /// chunks with no framing — this just yields each chunk as it arrives so
  /// the caller can render it live.
  ///
  /// When the AI provider is overloaded (rate limited / model at capacity),
  /// this waits [retryDelay] and tries again, up to [maxRetries] times,
  /// calling [onRetry] before each wait so the caller can let the user know.
  Stream<String> streamMessage(
    List<Map<String, dynamic>> messages, {
    void Function(int attempt, int maxAttempts)? onRetry,
  }) async* {
    for (var attempt = 0; ; attempt++) {
      final request = http.Request('POST', _uri('/chat'))
        ..headers.addAll(await _headers())
        ..body = jsonEncode({'messages': messages});

      final streamed = await _client.send(request);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final body = await streamed.stream.bytesToString();
        if (_isOverloaded(streamed.statusCode, body) && attempt < maxRetries) {
          onRetry?.call(attempt + 1, maxRetries);
          await Future.delayed(retryDelay);
          continue;
        }
        throw Exception(
          _isOverloaded(streamed.statusCode, body)
              ? 'A IA está com alta demanda no momento. Tente novamente em '
                    'alguns minutos.'
              : 'Falha na requisição (${streamed.statusCode}). Tente novamente.'
                    '${body.isEmpty ? '' : ' $body'}',
        );
      }

      yield* streamed.stream.transform(utf8.decoder);
      return;
    }
  }

  /// The backend wraps every upstream failure as a 502 with the provider's
  /// reason in the body, so a rate limit or "model overloaded" never shows up
  /// as its own status code here — this reads it out of the message instead.
  bool _isOverloaded(int statusCode, String body) {
    if (statusCode == 429 || statusCode == 503) return true;
    final lower = body.toLowerCase();
    return lower.contains('429') ||
        lower.contains('503') ||
        lower.contains('resource_exhausted') ||
        lower.contains('unavailable') ||
        lower.contains('overloaded');
  }

  Uri _uri(String path) {
    final normalizedBaseUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl
        : '$apiBaseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBaseUrl).resolve(normalizedPath);
  }

  Future<Map<String, String>> _headers() async {
    final accessToken = (await accessTokenProvider()).trim();
    if (accessToken.isEmpty) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }
}
