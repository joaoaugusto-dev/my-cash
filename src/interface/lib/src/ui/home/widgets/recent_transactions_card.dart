import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';
import '../../core/widgets/soft_panel.dart';

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    super.key,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
    required this.transactionColor,
    required this.transactionIcon,
    required this.onDelete,
    required this.onViewAll,
    required this.onViewTransaction,
    required this.deletingIds,
    required this.removingIds,
  });

  final List<FinancialTransaction> transactions;
  final String Function(double value) formatCurrency;
  final String Function(String isoDate) formatDate;
  final Color Function(FinancialTransaction transaction) transactionColor;
  final IconData Function(FinancialTransactionType type) transactionIcon;
  final void Function(String id) onDelete;
  final VoidCallback onViewAll;
  final void Function(FinancialTransaction) onViewTransaction;
  final Set<String> deletingIds;
  final Set<String> removingIds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SoftPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Últimas Transações',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todas',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < transactions.length; index++) ...[
            _CompactTransactionRow(
              key: ValueKey(transactions[index].id),
              transaction: transactions[index],
              formatCurrency: formatCurrency,
              formatDate: formatDate,
              color: transactionColor(transactions[index]),
              icon: transactionIcon(transactions[index].type),
              isDeleting: deletingIds.contains(transactions[index].id),
              isRemoving: removingIds.contains(transactions[index].id),
              onDelete: () => onDelete(transactions[index].id),
              onTap: () => onViewTransaction(transactions[index]),
            ),
            if (index != transactions.length - 1)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 8,
                color: colorScheme.outline.withValues(alpha: 0.58),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactTransactionRow extends StatelessWidget {
  const _CompactTransactionRow({
    super.key,
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
    required this.color,
    required this.icon,
    required this.onDelete,
    this.isDeleting = false,
    this.isRemoving = false,
    this.onTap,
  });

  final FinancialTransaction transaction;
  final String Function(double value) formatCurrency;
  final String Function(String isoDate) formatDate;
  final Color color;
  final IconData icon;
  final VoidCallback onDelete;
  final bool isDeleting;
  final bool isRemoving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sign = transaction.type == FinancialTransactionType.income
        ? '+ '
        : '- ';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isRemoving ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDate(transaction.occurredAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$sign${formatCurrency(transaction.amount)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                child: isDeleting
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Excluir lançamento',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
