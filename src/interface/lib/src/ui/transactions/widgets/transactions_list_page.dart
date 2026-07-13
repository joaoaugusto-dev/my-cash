import 'package:flutter/material.dart';

import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/data/services/transactions_api_service.dart';
import '../../core/widgets/staggered_fade_in.dart';
import 'transaction_detail_sheet.dart';
import 'transactions_list_widgets.dart';

class TransactionsListPage extends StatefulWidget {
  const TransactionsListPage({
    super.key,
    required this.apiService,
    required this.refreshTrigger,
    required this.onDataChanged,
  });

  final TransactionsApiService apiService;
  final ValueNotifier<int> refreshTrigger;
  final VoidCallback onDataChanged;

  @override
  State<TransactionsListPage> createState() => _TransactionsListPageState();
}

class _TransactionsListPageState extends State<TransactionsListPage> {
  final String _selectedMonth = _currentMonth();
  FinancialDashboard? _cachedDashboard;
  FinancialTransactionType? _filterType;
  final Set<String> _deletingIds = {};
  final Set<String> _removingIds = {};

  static String _currentMonth() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshTrigger.addListener(_onRefreshTriggered);
  }

  @override
  void dispose() {
    widget.refreshTrigger.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onRefreshTriggered() {
    _load();
  }

  void _load() {
    widget.apiService.fetchDashboard(month: _selectedMonth).then((dashboard) {
      if (mounted) setState(() => _cachedDashboard = dashboard);
    });
  }

  Future<void> _handleDelete(String id) async {
    if (_deletingIds.contains(id) || _removingIds.contains(id)) return;
    setState(() => _deletingIds.add(id));
    try {
      await widget.apiService.deleteTransaction(id);
      if (!mounted) return;
      setState(() {
        _deletingIds.remove(id);
        _removingIds.add(id);
      });
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final dashboard = _cachedDashboard;
      if (dashboard != null) {
        final updated = dashboard.transactions
            .where((t) => t.id != id)
            .toList();
        setState(() {
          _cachedDashboard = FinancialDashboard(
            summary: dashboard.summary,
            transactions: updated,
          );
          _removingIds.remove(id);
        });
        widget.onDataChanged();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao remover. Tente novamente.')),
      );
    }
  }

  void _showTransactionDetail(FinancialTransaction tx) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar detalhes',
      pageBuilder: (context, animation, secondaryAnimation) =>
          TransactionDetailSheet(transaction: tx),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  List<FinancialTransaction> get _filteredTransactions {
    final tx = _cachedDashboard?.transactions ?? [];
    if (_filterType == null) return tx;
    return tx.where((t) => t.type == _filterType).toList();
  }

  List<MapEntry<DateTime, List<FinancialTransaction>>> _groupByDate(
    List<FinancialTransaction> transactions,
  ) {
    final map = <DateTime, List<FinancialTransaction>>{};
    for (final t in transactions) {
      final date = DateTime.parse(t.occurredAt).toLocal();
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

  String _formatCurrency(double value) {
    final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $absolute';
  }

  Color _transactionColor(FinancialTransactionType type) {
    final colorScheme = Theme.of(context).colorScheme;
    return type == FinancialTransactionType.income
        ? colorScheme.tertiary
        : colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => _load(),
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
                      const SizedBox(height: 16),
                      FilterBar(
                        selected: _filterType,
                        onChanged: (type) => setState(() => _filterType = type),
                      ),
                      const SizedBox(height: 20),
                      _buildContent(),
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

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final dashboard = _cachedDashboard;

    if (dashboard == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
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

    final grouped = _groupByDate(_filteredTransactions);

    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(28),
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
                  : 'Nenhuma transação neste mês.',
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
                formatCurrency: _formatCurrency,
                color: _transactionColor(tx.type),
                isDeleting: _deletingIds.contains(tx.id),
                isRemoving: _removingIds.contains(tx.id),
                onDelete: () => _handleDelete(tx.id),
                onTap: () => _showTransactionDetail(tx),
              ),
            ),
        ],
      ],
    );
  }
}
