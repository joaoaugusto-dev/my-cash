import 'package:my_cash/src/domain/models/credit_card.dart';

/// Ranks [cards] from best to worst to spend on today: more days until the
/// invoice closes (longer float) and more of the limit still free both push
/// a card up; a card at or over its limit drops to the bottom automatically
/// since its score collapses to ~0, no extra branching needed.
List<CreditCard> rankCards(
  List<CreditCard> cards,
  Map<String, double> spentByCardId, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final ranked = [...cards];
  ranked.sort(
    (a, b) => _cardScore(
      b,
      spentByCardId,
      today,
    ).compareTo(_cardScore(a, spentByCardId, today)),
  );
  return ranked;
}

double _cardScore(
  CreditCard card,
  Map<String, double> spentByCardId,
  DateTime today,
) {
  final spent = spentByCardId[card.id] ?? 0;
  final usageRatio = card.limitAmount <= 0
      ? 1.0
      : (spent / card.limitAmount).clamp(0.0, 1.0);
  return daysUntilNextClosing(card.closingDay, today) * (1 - usageRatio);
}

/// The best card to use today (see [rankCards]), or null if there are none.
CreditCard? recommendBestCard(
  List<CreditCard> cards, {
  Map<String, double> spentByCardId = const {},
  DateTime? now,
}) {
  if (cards.isEmpty) return null;
  return rankCards(cards, spentByCardId, now: now).first;
}

/// [closingDay]'s next occurrence from [today]: this month if still ahead,
/// otherwise next month.
DateTime nextClosingDate(int closingDay, DateTime today) {
  return closingDay > today.day
      ? _clampedDate(today.year, today.month, closingDay)
      : _clampedDate(today.year, today.month + 1, closingDay);
}

/// Days from [today] until [closingDay]'s next occurrence.
int daysUntilNextClosing(int closingDay, DateTime today) {
  final next = nextClosingDate(closingDay, today);
  return next.difference(DateTime(today.year, today.month, today.day)).inDays;
}

/// Builds year/month/day, clamping [day] to the last day of the month and
/// rolling [month] over into following years.
DateTime _clampedDate(int year, int month, int day) {
  final normalizedYear = year + (month - 1) ~/ 12;
  final normalizedMonth = (month - 1) % 12 + 1;
  final daysInMonth = DateTime(normalizedYear, normalizedMonth + 1, 0).day;
  return DateTime(
    normalizedYear,
    normalizedMonth,
    day > daysInMonth ? daysInMonth : day,
  );
}
