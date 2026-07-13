import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';

class TransactionDetailSheet extends StatefulWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final FinancialTransaction transaction;

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeIn = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  void _close() {
    _controller.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $absolute';
  }

  String _formatFullDate(String isoDate) {
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return isoDate;
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.transaction;
    final isIncome = tx.type == FinancialTransactionType.income;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withValues(alpha: 0.35 * _fadeIn.value),
            child: Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: ScaleTransition(
                  scale: _scale,
                  child: GestureDetector(
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(
                              alpha: isDark ? 0.92 : 0.88,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 12, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color:
                                            (isIncome
                                                    ? colorScheme.tertiary
                                                    : colorScheme.error)
                                                .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isIncome
                                            ? Icons.arrow_downward_rounded
                                            : Icons.arrow_upward_rounded,
                                        size: 24,
                                        color: isIncome
                                            ? colorScheme.tertiary
                                            : colorScheme.error,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            isIncome ? 'Receita' : 'Despesa',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: isIncome
                                                      ? colorScheme.tertiary
                                                      : colorScheme.error,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tx.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fechar',
                                      onPressed: _close,
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 22,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  '${isIncome ? '+' : '-'} ${_formatCurrency(tx.amount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: isIncome
                                            ? colorScheme.tertiary
                                            : colorScheme.error,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface.withValues(
                                      alpha: isDark ? 0.5 : 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colorScheme.outline.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _DetailRow(
                                        icon: Icons.sell_rounded,
                                        label: 'Categoria',
                                        value: tx.category,
                                      ),
                                      const SizedBox(height: 14),
                                      _DetailRow(
                                        icon: Icons.calendar_month_rounded,
                                        label: 'Data',
                                        value: _formatFullDate(tx.occurredAt),
                                      ),
                                      if (tx.source != null &&
                                          tx.source!.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        _DetailRow(
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                          label: 'Pagamento',
                                          value: tx.source!,
                                        ),
                                      ],
                                      if (tx.notes != null &&
                                          tx.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        _DetailRow(
                                          icon: Icons.description_rounded,
                                          label: 'Observações',
                                          value: tx.notes!,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
