import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cash/src/domain/models/card_brand.dart';
import 'package:my_cash/src/data/services/cards_api_service.dart';
import 'package:my_cash/src/ui/cards/widgets/cards_page.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';
import 'package:my_cash/src/ui/core/widgets/composer_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('CardsPage shows empty state with no cards', (tester) async {
    final apiService = CardsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async => http.Response('[]', 200)),
    );

    await tester.pumpWidget(
      _wrap(
        CardsPage(
          apiService: apiService,
          refreshTrigger: ValueNotifier<int>(0),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nenhum cartão cadastrado'), findsOneWidget);
  });

  testWidgets('CardsPage shows the invoice usage percentage for a card', (
    tester,
  ) async {
    final apiService = CardsApiService(
      apiBaseUrl: 'https://api.example.com',
      accessTokenProvider: () => 'token-123',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'card-1',
              'userId': 'user-1',
              'name': 'Nubank',
              'brand': 'Visa',
              'lastDigits': '1234',
              'limitAmount': 1000,
              'closingDay': 10,
              'dueDay': 17,
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ]),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      _wrap(
        CardsPage(
          apiService: apiService,
          refreshTrigger: ValueNotifier<int>(0),
          spentByCardId: const {'card-1': 500},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('Fatura estimada'), findsOneWidget);
  });

  testWidgets('CardPreview shows masked digits and custom brand label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CardPreview(
          brand: CardBrand.outra,
          customBrandLabel: 'Loja X',
          nickname: '',
          lastDigits: '4321',
          color: Color(0xFF7C3AED),
        ),
      ),
    );

    expect(find.textContaining('4321'), findsOneWidget);
    expect(find.text('LOJA X'), findsOneWidget);
    expect(find.text('MEU CARTÃO'), findsOneWidget);
  });

  testWidgets('CardPreview renders a known brand svg logo without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CardPreview(
          brand: CardBrand.visa,
          customBrandLabel: '',
          nickname: 'Teste',
          lastDigits: '1234',
          color: Color(0xFF2563EB),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('CardComposerSheet validates required fields before submit', (
    tester,
  ) async {
    var submitted = false;

    await tester.pumpWidget(
      _wrap(
        CardComposerSheet(
          onSubmit: (card) async {
            submitted = true;
          },
        ),
      ),
    );

    await tester.ensureVisible(find.text('Salvar cartão'));
    await tester.tap(find.text('Salvar cartão'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Dê um apelido ao cartão'), findsOneWidget);
  });

  testWidgets('CardComposerSheet submits a valid card', (tester) async {
    CreditCard? submittedCard;

    await tester.pumpWidget(
      _wrap(
        CardComposerSheet(
          onSubmit: (card) async {
            submittedCard = card;
          },
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Apelido do cartão'),
      'Nubank',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Últimos 4 dígitos'),
      '1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Limite total'),
      '500000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fechamento'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vencimento'),
      '17',
    );

    await tester.ensureVisible(find.text('Salvar cartão'));
    await tester.tap(find.text('Salvar cartão'));
    await tester.pumpAndSettle();

    expect(submittedCard, isNotNull);
    expect(submittedCard!.name, 'Nubank');
    expect(submittedCard!.lastDigits, '1234');
    expect(submittedCard!.limitAmount, 5000.0);
    expect(submittedCard!.closingDay, 10);
    expect(submittedCard!.dueDay, 17);
  });

  testWidgets(
    'CardComposerSheet requires a custom name when brand is "Outra"',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CardComposerSheet(onSubmit: (card) async {})),
      );

      final brandField = find.widgetWithText(ComposerSelectorField, 'Bandeira');
      await tester.ensureVisible(brandField);
      await tester.tap(brandField);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Outra'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Nome da bandeira'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Salvar cartão'));
      await tester.tap(find.text('Salvar cartão'));
      await tester.pump();

      expect(find.text('Informe o nome da bandeira'), findsOneWidget);
    },
  );

  testWidgets(
    'CardComposerSheet prefills fields and deletes when editing',
    (tester) async {
      final existing = CreditCard(
        id: 'card-1',
        userId: 'user-1',
        name: 'Nubank',
        brand: 'Visa',
        lastDigits: '1234',
        limitAmount: 5000,
        closingDay: 10,
        dueDay: 17,
        createdAt: '2026-01-01T00:00:00.000Z',
        updatedAt: '2026-01-01T00:00:00.000Z',
        color: '#16A34A',
      );
      var deleted = false;

      await tester.pumpWidget(
        _wrap(
          CardComposerSheet(
            existingCard: existing,
            onSubmit: (card) async {},
            onDelete: () async {
              deleted = true;
            },
          ),
        ),
      );

      expect(find.text('Editar cartão'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Apelido do cartão'),
        findsOneWidget,
      );
      expect(find.text('Salvar alterações'), findsOneWidget);

      final deleteButton = find.text('Excluir cartão');
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    },
  );
}
