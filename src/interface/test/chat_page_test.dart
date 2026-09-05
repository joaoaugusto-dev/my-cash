import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_cash/src/data/services/chat_api_service.dart';
import 'package:my_cash/src/ui/chat/widgets/chat_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sending a text message shows the user bubble and the reply', (
    tester,
  ) async {
    final client = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.fromIterable([utf8.encode('Ano'), utf8.encode('tado!')]),
        200,
      );
    });
    final apiService = ChatApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatPage(apiService: apiService, onDataChanged: () {}))),
    );

    await tester.enterText(
      find.byType(TextField),
      'Comprei um lanche por 30 reais',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Comprei um lanche por 30 reais'), findsOneWidget);
    expect(find.text('Anotado!'), findsOneWidget);
  });

  testWidgets('reopening the chat restores the previous conversation', (
    tester,
  ) async {
    final apiService = ChatApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode('Anotado!')]),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatPage(apiService: apiService, onDataChanged: () {}))),
    );
    await tester.enterText(find.byType(TextField), 'Recebi 500 de freela');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Simulate the app being reopened: a brand new ChatPage/State.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatPage(apiService: apiService, onDataChanged: () {}))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recebi 500 de freela'), findsOneWidget);
    expect(find.text('Anotado!'), findsOneWidget);
  });

  testWidgets(
    'a create_transaction call shows a preview card instead of saving right away',
    (tester) async {
      var refreshes = 0;
      final apiService = ChatApiService(
        apiBaseUrl: 'https://api.example.com',
        accessTokenProvider: () => 'token-123',
        client: MockClient.streaming((request, bodyStream) async {
          if (request.url.path.endsWith('/chat/confirm')) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"id":"tx-1"}')),
              200,
            );
          }
          return http.StreamedResponse(
            // The marker is split across chunks, as it can be on the wire.
            Stream.fromIterable([
              utf8.encode('Beleza! [[mycash:pending:{"tool":"create_'),
              utf8.encode(
                'transaction","args":{"title":"Mercado","amount":50}}]]',
              ),
            ]),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPage(
              apiService: apiService,
              onDataChanged: () => refreshes++,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'gastei 50 no mercado');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Beleza!'), findsOneWidget);
      expect(find.textContaining('mycash:pending'), findsNothing);
      expect(find.text('Registrar transação'), findsOneWidget);
      expect(refreshes, 0);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(refreshes, 1);
      expect(find.text('Salvo'), findsOneWidget);
    },
  );
}
