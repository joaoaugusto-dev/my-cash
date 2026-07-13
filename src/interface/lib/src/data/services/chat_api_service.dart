import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  ChatApiService({
    required this.apiBaseUrl,
    required this.accessTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final FutureOr<String> Function() accessTokenProvider;
  final http.Client _client;

  /// [messages] is the full conversation so far, oldest first, each entry
  /// shaped as {'role': 'user'|'assistant', 'content': '...'}.
  ///
  /// The backend streams the reply as it's generated (proxying OpenRouter's
  /// SSE) and writes plain UTF-8 text chunks with no framing — this just
  /// yields each chunk as it arrives so the caller can render it live.
  Stream<String> streamMessage(List<Map<String, String>> messages) async* {
    final request = http.Request('POST', _uri('/chat'))
      ..headers.addAll(await _headers())
      ..body = jsonEncode({'messages': messages});

    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw Exception(
        'Falha na requisição (${streamed.statusCode}). Tente novamente.'
        '${body.isEmpty ? '' : ' $body'}',
      );
    }

    yield* streamed.stream.transform(utf8.decoder);
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
