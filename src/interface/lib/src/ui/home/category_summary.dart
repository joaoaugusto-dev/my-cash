import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';

class CategorySummary {
  const CategorySummary({
    required this.name,
    required this.amount,
    required this.percent,
    required this.icon,
    required this.color,
  });

  final String name;
  final double amount;
  final double percent;
  final IconData icon;
  final Color color;
}

/// Aggregates expense transactions into the top categories (plus an "Outros"
/// bucket for the tail) used by the dashboard breakdown and insight cards.
List<CategorySummary> buildCategorySummaries(
  List<FinancialTransaction> transactions,
) {
  final totals = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.type != FinancialTransactionType.expense) {
      continue;
    }
    totals.update(
      transaction.category,
      (value) => value + transaction.amount.abs(),
      ifAbsent: () => transaction.amount.abs(),
    );
  }

  final totalExpense = totals.values.fold<double>(
    0,
    (sum, amount) => sum + amount,
  );
  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final visibleEntries = entries.take(5).toList();
  final hiddenTotal = entries
      .skip(5)
      .fold<double>(0, (sum, entry) => sum + entry.value);
  if (hiddenTotal > 0) {
    visibleEntries.add(MapEntry('Outros', hiddenTotal));
  }

  return [
    for (var index = 0; index < visibleEntries.length; index++)
      CategorySummary(
        name: visibleEntries[index].key,
        amount: visibleEntries[index].value,
        percent: totalExpense <= 0
            ? 0
            : visibleEntries[index].value / totalExpense,
        icon: categoryIcon(visibleEntries[index].key),
        color: categoryColor(index),
      ),
  ];
}

IconData categoryIcon(String category) {
  final normalized = category.toLowerCase();
  if (normalized.contains('aliment') ||
      normalized.contains('cantina') ||
      normalized.contains('rest')) {
    return Icons.restaurant_rounded;
  }
  if (normalized.contains('trans')) {
    return Icons.directions_bus_filled_rounded;
  }
  if (normalized.contains('assin') ||
      normalized.contains('netflix') ||
      normalized.contains('stream')) {
    return Icons.subscriptions_rounded;
  }
  if (normalized.contains('compra') || normalized.contains('mercado')) {
    return Icons.shopping_bag_rounded;
  }
  if (normalized.contains('saúde') || normalized.contains('saude')) {
    return Icons.favorite_rounded;
  }
  return Icons.category_rounded;
}

Color categoryColor(int index) {
  const colors = [
    Color(0xFF8B5CF6),
    Color(0xFF58CF72),
    Color(0xFFFF5576),
    Color(0xFFFFD44D),
    Color(0xFF5B9BFF),
    Color(0xFFC9CCD3),
  ];
  return colors[index % colors.length];
}
