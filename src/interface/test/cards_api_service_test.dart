import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cash/src/data/services/cards_api_service.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';

void main() {
  test('fetchCards sends auth header and parses list', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token-123');

      return http.Response(
        jsonEncode([
          {
            'id': '1',
            'userId': 'user-1',
            'name': 'Nubank',
            'brand': 'Mastercard',
            'lastDigits': '1234',
            'limitAmount': 5000,
            'closingDay': 10,
            'createdAt': '2026-05-01T10:00:00.000Z',
            'updatedAt': '2026-05-01T10:00:00.000Z',
          },
        ]),
        200,
      );
    });

    final service = CardsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final cards = await service.fetchCards();

    expect(cards.length, 1);
    expect(cards.first.name, 'Nubank');
    expect(cards.first.lastDigits, '1234');
  });

  test('createCard posts payload and parses created item', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['name'], 'Nubank');
      expect(body['lastDigits'], '1234');

      return http.Response(
        jsonEncode({
          'id': 'created-1',
          'userId': 'user-1',
          'name': 'Nubank',
          'brand': 'Mastercard',
          'lastDigits': '1234',
          'limitAmount': 5000,
          'closingDay': 10,
          'createdAt': '2026-05-01T10:00:00.000Z',
          'updatedAt': '2026-05-01T10:00:00.000Z',
        }),
        201,
      );
    });

    final service = CardsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    final created = await service.createCard(
      CreditCard(
        id: 'pending',
        userId: 'pending',
        name: 'Nubank',
        brand: 'Mastercard',
        lastDigits: '1234',
        limitAmount: 5000,
        closingDay: 10,
        createdAt: '',
        updatedAt: '',
      ),
    );

    expect(created.id, 'created-1');
    expect(created.name, 'Nubank');
  });

  test('deleteCard sends DELETE to the right path', () async {
    Uri? requestedUrl;
    final client = MockClient((request) async {
      requestedUrl = request.url;
      return http.Response('', 204);
    });

    final service = CardsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: client,
    );

    await service.deleteCard('card-1');

    expect(requestedUrl.toString(), 'https://api.example.com/cards/card-1');
  });
}
