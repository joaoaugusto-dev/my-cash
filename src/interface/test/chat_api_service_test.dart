import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cash/src/data/services/chat_api_service.dart';

void main() {
  test('streamMessage posts payload and yields the streamed reply', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/chat');
      expect(request.headers['Authorization'], 'Bearer token-123');

      final body =
          jsonDecode(await bodyStream.bytesToString()) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      expect(messages, [
        {'role': 'user', 'content': 'Comprei um lanche por 30 reais'},
      ]);

      return http.StreamedResponse(
        Stream.fromIterable([utf8.encode('Ano'), utf8.encode('tado!')]),
        200,
      );
    });

    final service = ChatApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final chunks = await service
        .streamMessage([
          {'role': 'user', 'content': 'Comprei um lanche por 30 reais'},
        ])
        .toList();

    expect(chunks.join(), 'Anotado!');
  });

  test('streamMessage throws when the response status is not 2xx', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.fromIterable([utf8.encode('server exploded')]),
        500,
      );
    });

    final service = ChatApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    expect(
      service.streamMessage([
        {'role': 'user', 'content': 'oi'},
      ]).toList(),
      throwsA(isA<Exception>()),
    );
  });

  test('streamMessage throws when the session is empty', () async {
    final service = ChatApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => '',
      client: MockClient((request) async => http.Response('', 200)),
    );

    expect(
      service.streamMessage([
        {'role': 'user', 'content': 'oi'},
      ]).toList(),
      throwsA(isA<StateError>()),
    );
  });
}
