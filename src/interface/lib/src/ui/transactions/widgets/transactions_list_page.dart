import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';
import '../../../utils/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/staggered_fade_in.dart';
import '../../home/view_model/home_view_model.dart';
import 'transaction_composer_sheet.dart';
import 'transactions_list_widgets.dart';

/// Lists transactions for whatever period is currently selected on the home
/// tab — it reads [HomeViewModel.cachedDashboard] directly instead of
/// fetching its own, so the period always stays in sync with the home tab.
class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({super.key});

  @override
  State<TransactionsListPage> createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  FinancialTransactionType? _filterType;

  Future<void> _handleDelete(HomeViewModel vm, FinancialTransaction tx) async {
    String? scope;
    if (tx.installmentsTotal != null) {
      final confirmed = await showInstallmentDeleteConfirmDialog(context);
      if (!confirmed || !mounted) return;
    } else if (tx.isRecurring) {
      scope = await showRecurringDeleteScopeDialog(context);
      if (scope == null || !mounted) return;
    } else {
      final confirmed = await showDeleteConfirmDialog(context);
      if (!confirmed || !mounted) return;
    }

    try {
      await vm.deleteTransaction(tx.id, scope: scope);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover. Tente novamente.')),
      );
    }
  }

  Future<void> _openEditSheet(
    HomeViewModel vm,
    FinancialTransaction tx,
  ) async {
    final cards = await vm.cardsFuture ?? const [];
    if (!mounted) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RepaintBoundary(
          child: TransactionComposerSheet(
            initialTransaction: tx,
            cards: cards,
            spentByCardId: vm.spentByCardId,
            onSubmit: (transaction, {scope}) async {
              await vm.updateTransaction(transaction, scope: scope);
            },
          ),
        );
      },
    );

    if (updated == true && mounted) {
      vm.refreshDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento atualizado com sucesso.')),
      );
    }
  }

  List<FinancialTransaction> _filteredTransactions(HomeViewModel vm) {
    final tx = vm.cachedDashboard?.transactions ?? const [];
    if (_filterType == null) return tx;
    return tx.where((t) => t.type == _filterType).toList();
  }

  List<MapEntry<DateTime, List<FinancialTransaction>>> _groupByDate(
    List<FinancialTransaction> transactions,
  ) {
    final map = <DateTime, List<FinancialTransaction>>{};
    for (final t in transactions) {
      final date = parseCalendarDate(t.occurredAt) ?? DateTime.parse(t.occurredAt);
      final day = DateTime(date.year, date.month, date.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    final entries = map.entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  String _formatSectionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final weekday = weekdays[date.weekday % 7];

    if (date == today) return 'Hoje';
    if (date == yesterday) return 'Ontem';
    return '$dayStr/$monthStr - $weekday';
  }

  Color _transactionColor(FinancialTransactionType type) {
    final colorScheme = Theme.of(context).colorScheme;
    return type == FinancialTransactionType.income
        ? colorScheme.tertiary
        : colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final periodLabel = vm.visionMode == VisionMode.yearly
        ? vm.selectedYear
        : formatMonthLabel(vm.selectedMonth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => vm.refreshDashboard(),
            color: colorScheme.secondary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topPadding + 18,
                    20,
                    bottomPadding + 150,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Transações',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        periodLabel,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilterBar(
                        selected: _filterType,
                        onChanged: (type) => setState(() => _filterType = type),
                      ),
                      const SizedBox(height: 20),
                      _buildContent(vm),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(HomeViewModel vm) {
    final colorScheme = Theme.of(context).colorScheme;
    final dashboard = vm.cachedDashboard;

    if (dashboard == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.48),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.secondary),
              const SizedBox(height: 18),
              Text(
                'Carregando transações...',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByDate(_filteredTransactions(vm));

    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.48),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 52,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _filterType != null
                  ? 'Nenhuma transação encontrada para este filtro.'
                  : 'Nenhuma transação neste período.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    int rowIndex = 0;
    return Column(
      children: [
        for (final entry in grouped) ...[
          DateSectionHeader(
            date: entry.key,
            label: _formatSectionDate(entry.key),
          ),
          for (final tx in entry.value)
            StaggeredFadeIn(
              key: ValueKey('staggered-${tx.id}'),
              index: rowIndex++,
              child: TransactionListRow(
                transaction: tx,
                formatCurrency: formatCurrency,
                color: _transactionColor(tx.type),
                isDeleting: vm.deletingIds.contains(tx.id),
                isRemoving: vm.removingIds.contains(tx.id),
                onDelete: () => _handleDelete(vm, tx),
                onTap: () => _openEditSheet(vm, tx),
              ),
            ),
        ],
      ],
    );
  }
}
