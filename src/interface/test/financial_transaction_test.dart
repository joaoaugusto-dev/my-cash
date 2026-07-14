import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/domain/models/financial_transaction.dart';

FinancialTransaction _transaction({String? cardId}) {
  return FinancialTransaction(
    id: 'id',
    userId: 'user-1',
    title: 'Compra',
    amount: 100,
    type: FinancialTransactionType.expense,
    category: 'Compras',
    occurredAt: '2026-07-01T00:00:00.000Z',
    createdAt: '2026-07-01T00:00:00.000Z',
    updatedAt: '2026-07-01T00:00:00.000Z',
    cardId: cardId,
  );
}

void main() {
  test('toCreateJson omits cardId when the transaction has none', () {
    expect(_transaction().toCreateJson().containsKey('cardId'), isFalse);
  });

  test('toCreateJson includes cardId when set', () {
    expect(_transaction(cardId: 'card-1').toCreateJson()['cardId'], 'card-1');
  });

  test('fromJson round-trips cardId', () {
    final parsed = FinancialTransaction.fromJson({
      'id': 'id',
      'userId': 'user-1',
      'title': 'Compra',
      'amount': 100,
      'type': 'expense',
      'category': 'Compras',
      'occurredAt': '2026-07-01T00:00:00.000Z',
      'cardId': 'card-1',
      'createdAt': '2026-07-01T00:00:00.000Z',
      'updatedAt': '2026-07-01T00:00:00.000Z',
    });

    expect(parsed.cardId, 'card-1');
  });

  test('toCreateJson includes installmentsTotal when set', () {
    final json = FinancialTransaction(
      id: 'pending',
      userId: 'pending',
      title: 'Notebook',
      amount: 3000,
      type: FinancialTransactionType.expense,
      category: 'Compras',
      occurredAt: '2026-07-01T00:00:00.000Z',
      createdAt: '2026-07-01T00:00:00.000Z',
      updatedAt: '2026-07-01T00:00:00.000Z',
      installmentsTotal: 3,
    ).toCreateJson();

    expect(json['installmentsTotal'], 3);
  });

  test('isRecurring is true when seriesId or recurrenceFrequency is set', () {
    expect(_transaction().isRecurring, isFalse);

    final parsed = FinancialTransaction.fromJson({
      'id': 'anchor-1::2026-07-05T00:00:00.000Z',
      'userId': 'user-1',
      'title': 'Aluguel',
      'amount': 1500,
      'type': 'expense',
      'category': 'Moradia',
      'occurredAt': '2026-07-05T00:00:00.000Z',
      'createdAt': '2026-01-05T00:00:00.000Z',
      'updatedAt': '2026-01-05T00:00:00.000Z',
      'seriesId': 'anchor-1',
      'recurrenceFrequency': 'monthly',
    });

    expect(parsed.isRecurring, isTrue);
  });
}
