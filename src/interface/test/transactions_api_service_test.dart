import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/data/services/transactions_api_service.dart';

void main() {
  test('fetchDashboard sends auth header and parses summary', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token-123');

      if (request.url.path.endsWith('/summary')) {
        return http.Response(
          jsonEncode({
            'month': '2026-05',
            'income': 5100,
            'expense': 230.5,
            'balance': 4869.5,
            'entriesCount': 1,
            'exitsCount': 2,
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode([
          {
            'id': '1',
            'userId': 'user-1',
            'title': 'Salario',
            'amount': 5100,
            'type': 'income',
            'category': 'Trabalho',
            'occurredAt': '2026-05-01T10:00:00.000Z',
            'notes': null,
            'source': null,
            'createdAt': '2026-05-01T10:00:00.000Z',
            'updatedAt': '2026-05-01T10:00:00.000Z',
          },
        ]),
        200,
      );
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final dashboard = await service.fetchDashboard(month: '2026-05');

    expect(dashboard.summary.balance, 4869.5);
    expect(dashboard.transactions.length, 1);
    expect(dashboard.transactions.first.title, 'Salario');
  });

  test('createTransaction posts payload and parses created item', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer token-123');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['title'], 'Lanche');
      expect(body['type'], 'expense');

      return http.Response(
        jsonEncode({
          'id': 'created-1',
          'userId': 'user-1',
          'title': 'Lanche',
          'amount': 32,
          'type': 'expense',
          'category': 'Alimentação',
          'occurredAt': '2026-05-02T10:00:00.000Z',
          'notes': null,
          'source': null,
          'createdAt': '2026-05-02T10:00:00.000Z',
          'updatedAt': '2026-05-02T10:00:00.000Z',
        }),
        201,
      );
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final created = await service.createTransaction(
      FinancialTransaction(
        id: 'pending',
        userId: 'pending',
        title: 'Lanche',
        amount: 32,
        type: FinancialTransactionType.expense,
        category: 'Alimentação',
        occurredAt: '2026-05-02T10:00:00.000Z',
        createdAt: '2026-05-02T10:00:00.000Z',
        updatedAt: '2026-05-02T10:00:00.000Z',
      ),
    );

    expect(created.id, 'created-1');
    expect(created.title, 'Lanche');
  });

  test('updateTransaction sends PATCH to the transaction id', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/transactions/tx-1');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['title'], 'Lanche editado');

      return http.Response(
        jsonEncode({
          'id': 'tx-1',
          'userId': 'user-1',
          'title': 'Lanche editado',
          'amount': 40,
          'type': 'expense',
          'category': 'Alimentação',
          'occurredAt': '2026-05-02T10:00:00.000Z',
          'notes': null,
          'source': null,
          'createdAt': '2026-05-02T10:00:00.000Z',
          'updatedAt': '2026-05-03T10:00:00.000Z',
        }),
        200,
      );
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final updated = await service.updateTransaction(
      'tx-1',
      FinancialTransaction(
        id: 'tx-1',
        userId: 'user-1',
        title: 'Lanche editado',
        amount: 40,
        type: FinancialTransactionType.expense,
        category: 'Alimentação',
        occurredAt: '2026-05-02T10:00:00.000Z',
        createdAt: '2026-05-02T10:00:00.000Z',
        updatedAt: '2026-05-03T10:00:00.000Z',
      ),
    );

    expect(updated.title, 'Lanche editado');
    expect(updated.amount, 40);
  });

  test('updateTransaction forwards the edit scope as a query param', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['scope'], 'forward');

      return http.Response(
        jsonEncode({
          'id': 'anchor-1',
          'userId': 'user-1',
          'title': 'Aluguel',
          'amount': 1800,
          'type': 'expense',
          'category': 'Moradia',
          'occurredAt': '2026-07-05T00:00:00.000Z',
          'createdAt': '2026-01-05T00:00:00.000Z',
          'updatedAt': '2026-07-05T00:00:00.000Z',
        }),
        200,
      );
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    await service.updateTransaction(
      'anchor-1::2026-07-05T00:00:00.000Z',
      FinancialTransaction(
        id: 'anchor-1::2026-07-05T00:00:00.000Z',
        userId: 'user-1',
        title: 'Aluguel',
        amount: 1800,
        type: FinancialTransactionType.expense,
        category: 'Moradia',
        occurredAt: '2026-07-05T00:00:00.000Z',
        createdAt: '2026-01-05T00:00:00.000Z',
        updatedAt: '2026-07-05T00:00:00.000Z',
      ),
      scope: 'forward',
    );
  });

  test(
    'deleteTransaction encodes a recurring occurrence id and forwards scope',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(
          request.url.path,
          '/transactions/anchor-1%3A%3A2026-07-05T00%3A00%3A00.000Z',
        );
        expect(request.url.queryParameters['scope'], 'forward');

        return http.Response(jsonEncode({'deleted': true}), 200);
      });

      final service = TransactionsApiService(
        apiBaseUrl: 'https://api.example.com',
        accessTokenProvider: () => 'token-123',
        client: client,
      );

      await service.deleteTransaction(
        'anchor-1::2026-07-05T00:00:00.000Z',
        scope: 'forward',
      );
    },
  );

  test('uses the latest access token for every request', () async {
    var issuedTokenCounter = 0;
    final authorizationHeaders = <String>[];
    final client = MockClient((request) async {
      authorizationHeaders.add(request.headers['Authorization'] ?? '');
      expect(request.url.queryParameters.containsKey('access_token'), isFalse);

      if (request.url.path.endsWith('/transactions')) {
        return http.Response(jsonEncode([]), 200);
      }

      return http.Response(
        jsonEncode({
          'month': '2026-05',
          'income': 0,
          'expense': 0,
          'balance': 0,
          'entriesCount': 0,
          'exitsCount': 0,
        }),
        200,
      );
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () {
        issuedTokenCounter += 1;
        return 'token-$issuedTokenCounter';
      },
      client: client,
    );

    await service.fetchDashboard(month: '2026-05');

    expect(
      authorizationHeaders,
      containsAll(['Bearer token-1', 'Bearer token-2']),
    );
  });

  test('normalizes base urls with trailing slash and /api path', () async {
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);

      if (request.url.path.endsWith('/summary')) {
        return http.Response(
          jsonEncode({
            'month': '2026-05',
            'income': 0,
            'expense': 0,
            'balance': 0,
            'entriesCount': 0,
            'exitsCount': 0,
          }),
          200,
        );
      }

      return http.Response(jsonEncode([]), 200);
    });

    final service = TransactionsApiService(
      apiBaseUrl: 'https://api.example.com/api/',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    await service.fetchDashboard(month: '2026-05');

    expect(
      requestedUrls.map((url) => url.toString()),
      containsAll([
        'https://api.example.com/api/transactions/summary?month=2026-05',
        'https://api.example.com/api/transactions?month=2026-05',
      ]),
    );
  });
}
