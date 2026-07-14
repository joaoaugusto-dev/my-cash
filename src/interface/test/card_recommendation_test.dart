import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/domain/models/card_recommendation.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';

CreditCard _card({required String id, required int closingDay}) {
  return CreditCard(
    id: id,
    userId: 'user-1',
    name: 'Card $id',
    brand: 'Visa',
    lastDigits: '1234',
    limitAmount: 1000,
    closingDay: closingDay,
    createdAt: '',
    updatedAt: '',
  );
}

void main() {
  final today = DateTime(2026, 7, 10);

  test('recommendBestCard returns null for an empty list', () {
    expect(recommendBestCard([], now: today), isNull);
  });

  test('recommendBestCard returns the only card when there is one', () {
    final card = _card(id: 'a', closingDay: 15);
    expect(recommendBestCard([card], now: today), card);
  });

  test('prefers the card that closed most recently (longest float)', () {
    final justClosed = _card(
      id: 'just-closed',
      closingDay: 10,
    ); // closes today -> next month
    final closingSoon = _card(
      id: 'closing-soon',
      closingDay: 12,
    ); // closes in 2 days
    expect(
      recommendBestCard([closingSoon, justClosed], now: today),
      justClosed,
    );
  });

  test(
    'daysUntilNextClosing counts within the current month when closing day is ahead',
    () {
      expect(daysUntilNextClosing(15, today), 5);
    },
  );

  test(
    'daysUntilNextClosing rolls over to next month once the closing day has passed',
    () {
      // today.day == 10, closingDay == 10 is treated as already closed today.
      expect(daysUntilNextClosing(10, today), 31);
      expect(daysUntilNextClosing(1, today), 22);
    },
  );

  test('daysUntilNextClosing clamps to the last day of short months', () {
    final endOfJanuary = DateTime(2026, 1, 31);
    // Next month is February (28 days in 2026, not a leap year) -> day 31 clamps to 28.
    expect(daysUntilNextClosing(31, endOfJanuary), 28);
  });

  test('daysUntilNextClosing rolls over into the next year from December', () {
    final midDecember = DateTime(2026, 12, 15);
    expect(daysUntilNextClosing(5, midDecember), 21);
  });

  test(
    'rankCards deprioritizes a card near its limit even with the longest float',
    () {
      final justClosed = _card(
        id: 'near-limit',
        closingDay: 10,
      ); // best float today
      final closingSoon = _card(id: 'has-room', closingDay: 12);

      final ranked = rankCards(
        [justClosed, closingSoon],
        {'near-limit': 950}, // 95% of its 1000 limit used
        now: today,
      );

      expect(ranked.first.id, 'has-room');
    },
  );

  test(
    'recommendBestCard picks a fully available card over an over-limit one',
    () {
      final overLimit = _card(id: 'over-limit', closingDay: 10);
      final available = _card(id: 'available', closingDay: 11);

      final recommended = recommendBestCard(
        [overLimit, available],
        spentByCardId: {'over-limit': 1200}, // over its 1000 limit
        now: today,
      );

      expect(recommended?.id, 'available');
    },
  );
}
