import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';
import '../../core/widgets/soft_panel.dart';
import '../category_summary.dart';

/// What matters most for a user's financial control, in priority order:
/// 1. Did they spend more than they earned? (immediate red flag)
/// 2. How much of their income did they keep? (the core health metric)
/// 3. Where is most of the money going? (actionable detail)
class AiInsightCard extends StatelessWidget {
  const AiInsightCard({
    super.key,
    required this.categorySummaries,
    required this.summary,
    required this.formatCurrency,
  });

  final List<CategorySummary> categorySummaries;
  final TransactionSummary summary;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topCategory = categorySummaries.isEmpty
        ? null
        : categorySummaries.first;

    final Color accent;
    final IconData icon;
    final String title;
    final String subtitle;

    if (topCategory == null || summary.income <= 0) {
      accent = colorScheme.primary;
      icon = Icons.psychology_alt_rounded;
      title = 'Crie lançamentos para liberar insights automáticos.';
      subtitle = 'Assim que houver renda e gastos, mostramos sua saúde financeira aqui.';
    } else if (summary.balance < 0) {
      accent = colorScheme.error;
      icon = Icons.trending_down_rounded;
      title = 'Você gastou ${formatCurrency(summary.balance.abs())} a mais do que ganhou.';
      subtitle = 'Maior gasto: ${topCategory.name} (${formatCurrency(topCategory.amount)}).';
    } else {
      final savingsRate = summary.balance / summary.income;
      final percent = '${(savingsRate * 100).round()}%';
      accent = colorScheme.tertiary;
      icon = Icons.savings_rounded;
      title = savingsRate < 0.10
          ? 'Você guardou só $percent da sua renda. Tente poupar ao menos 10%.'
          : 'Você guardou $percent da sua renda este mês.';
      subtitle = 'Maior gasto: ${topCategory.name} (${formatCurrency(topCategory.amount)}, ${(topCategory.percent * 100).round()}% do total).';
    }

    return SoftPanel(
      padding: const EdgeInsets.all(14),
      tint: accent.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 38,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '* Sua saúde financeira',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
