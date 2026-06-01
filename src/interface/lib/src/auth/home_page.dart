import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';
import '../finance/financial_transaction.dart';
import '../finance/transactions_api_service.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/finance_stat_card.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.themeController,
  });

  final Session session;
  final AppThemeController themeController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TransactionsApiService _apiService;
  Future<FinancialDashboard>? _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _apiService = TransactionsApiService(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessToken: widget.session.accessToken,
    );
    _dashboardFuture = _loadDashboard();
  }

  Future<FinancialDashboard> _loadDashboard() {
    return _apiService.fetchDashboard();
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  String _formatCurrency(double value) {
    final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $absolute';
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) {
      return isoDate;
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Color _transactionColor(BuildContext context, FinancialTransactionType type) {
    final colorScheme = Theme.of(context).colorScheme;
    return type == FinancialTransactionType.income
        ? colorScheme.tertiary
        : colorScheme.error;
  }

  IconData _transactionIcon(FinancialTransactionType type) {
    return type == FinancialTransactionType.income
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
  }

  Future<void> _openCreateTransactionSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.95),
      builder: (context) {
        return _TransactionComposerSheet(
          onSubmit: (transaction) async {
            await _apiService.createTransaction(transaction);
          },
        );
      },
    );

    if (created == true && mounted) {
      _refreshDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo com sucesso.')),
      );
    }
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      await _apiService.deleteTransaction(id);
      if (!mounted) {
        return;
      }

      _refreshDashboard();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lançamento removido.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao remover lançamento: $error')),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          session: widget.session,
          themeController: widget.themeController,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userEmail =
        currentUser?.email ?? widget.session.user.email ?? 'Conta autenticada';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTransactionSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo lançamento'),
      ),
      appBar: AppBar(
        title: const Text('MyCash'),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: colorScheme.onPrimary),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshDashboard(),
        child: FutureBuilder<FinancialDashboard>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final error = snapshot.error;
            final dashboard = snapshot.data;

            if (error != null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.warning_rounded,
                    size: 56,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Não foi possível carregar o painel.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _refreshDashboard,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              );
            }

            if (isLoading || dashboard == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final topTransactions = dashboard.transactions.take(8).toList();
            final netColor = dashboard.summary.balance >= 0
                ? colorScheme.tertiary
                : colorScheme.error;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _HeaderHero(
                  userEmail: userEmail,
                  month: dashboard.summary.month,
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width >= 900
                      ? 4
                      : 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.25,
                  children: [
                    FinanceStatCard(
                      title: 'Saldo',
                      value: _formatCurrency(dashboard.summary.balance),
                      subtitle: 'Resultado do mês',
                      icon: Icons.account_balance_wallet_rounded,
                      color: netColor,
                    ),
                    FinanceStatCard(
                      title: 'Entradas',
                      value: _formatCurrency(dashboard.summary.income),
                      subtitle: '${dashboard.summary.entriesCount} registros',
                      icon: Icons.trending_up_rounded,
                      color: colorScheme.tertiary,
                    ),
                    FinanceStatCard(
                      title: 'Saídas',
                      value: _formatCurrency(dashboard.summary.expense),
                      subtitle: '${dashboard.summary.exitsCount} registros',
                      icon: Icons.trending_down_rounded,
                      color: colorScheme.error,
                    ),
                    FinanceStatCard(
                      title: 'Movimentações',
                      value: '${dashboard.transactions.length}',
                      subtitle: 'Lançamentos no período',
                      icon: Icons.receipt_long_rounded,
                      color: colorScheme.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Últimos lançamentos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (topTransactions.isEmpty)
                  _EmptyStateCard(onCreate: _openCreateTransactionSheet)
                else
                  ...topTransactions.map(
                    (transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TransactionTile(
                        transaction: transaction,
                        formatCurrency: _formatCurrency,
                        formatDate: _formatDate,
                        color: _transactionColor(context, transaction.type),
                        icon: _transactionIcon(transaction.type),
                        onDelete: () => _deleteTransaction(transaction.id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({required this.userEmail, required this.month});

  final String userEmail;
  final String month;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1033), const Color(0xFF2E1A5C)]
              : [const Color(0xFF4C1D95), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withValues(alpha: isDark ? 0.2 : 0.24),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $userEmail',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Painel mensal de entradas e saídas sincronizado com a API.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Mês atual: $month',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
    required this.color,
    required this.icon,
    required this.onDelete,
  });

  final FinancialTransaction transaction;
  final String Function(double value) formatCurrency;
  final String Function(String isoDate) formatDate;
  final Color color;
  final IconData icon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.8,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          transaction.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${transaction.category} · ${formatDate(transaction.occurredAt)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(transaction.amount),
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Excluir lançamento',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.82,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inbox_rounded, size: 36, color: colorScheme.secondary),
          const SizedBox(height: 12),
          Text(
            'Nenhum lançamento encontrado.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Comece criando uma entrada ou saída para alimentar o painel mensal.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar lançamento'),
          ),
        ],
      ),
    );
  }
}

class _TransactionComposerSheet extends StatefulWidget {
  const _TransactionComposerSheet({required this.onSubmit});

  final Future<void> Function(FinancialTransaction transaction) onSubmit;

  @override
  State<_TransactionComposerSheet> createState() =>
      _TransactionComposerSheetState();
}

class _TransactionComposerSheetState extends State<_TransactionComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Alimentação');
  final _notesController = TextEditingController();
  final _sourceController = TextEditingController();
  final _dateController = TextEditingController();
  FinancialTransactionType _type = FinancialTransactionType.expense;
  DateTime _occurredAt = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncDateText();
  }

  void _syncDateText() {
    _dateController.text =
        '${_occurredAt.day.toString().padLeft(2, '0')}/${_occurredAt.month.toString().padLeft(2, '0')}/${_occurredAt.year}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _sourceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final transaction = FinancialTransaction(
        id: 'pending',
        userId: 'pending',
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        category: _categoryController.text.trim(),
        occurredAt: _occurredAt.toUtc().toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        source: _sourceController.text.trim().isEmpty
            ? null
            : _sourceController.text.trim(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      await widget.onSubmit(transaction);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar lançamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Novo lançamento',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe um título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Informe um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FinancialTransactionType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: FinancialTransactionType.income,
                    child: Text('Entrada'),
                  ),
                  DropdownMenuItem(
                    value: FinancialTransactionType.expense,
                    child: Text('Saída'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe uma categoria';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Data',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _occurredAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (selected != null) {
                        setState(() {
                          _occurredAt = selected;
                          _syncDateText();
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Origem',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Salvando...' : 'Salvar lançamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
