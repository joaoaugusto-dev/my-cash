import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_cash/src/ui/cards/widgets/cards_page.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';
import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/ui/core/theme/app_theme_controller.dart';
import 'package:my_cash/src/ui/onboarding/widgets/onboarding_tour.dart';
import 'package:my_cash/src/ui/settings/widgets/settings_page.dart';
import '../../../utils/formatters.dart';
import '../../core/widgets/animated_section.dart';
import '../../core/widgets/bottom_bar.dart';
import '../../core/widgets/finance_background.dart';
import '../../core/widgets/finance_stat_card.dart';
import '../../chat/widgets/chat_page.dart';
import '../../transactions/widgets/transaction_composer_sheet.dart';
import '../../transactions/widgets/transactions_list_page.dart';
import '../../transactions/widgets/transactions_list_widgets.dart';
import '../category_summary.dart';
import '../view_model/home_view_model.dart';
import 'ai_insight_card.dart';
import 'category_breakdown_card.dart';
import 'dashboard_states.dart';
import 'home_splash_overlay.dart';
import 'month_picker_sheet.dart';
import 'period_vision_row.dart';
import 'recent_transactions_card.dart';
import 'smart_card_recommendation.dart';
import 'stat_cards_scroller.dart';
import 'top_identity_bar.dart';
import 'year_picker_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.themeController,
  });

  final Session session;
  final AppThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) =>
          HomeViewModel(session: session, themeController: themeController)
            ..init(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _selectedNavIndex = 0;
  late final PageController _pageController;
  late final Future<void> _initialLoad;
  final OnboardingTargets _tourTargets = OnboardingTargets();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedNavIndex);
    final vm = context.read<HomeViewModel>();
    _initialLoad = Future.wait([
      vm.dashboardFuture ?? Future.value(),
      vm.cardsFuture ?? Future.value(),
    ]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Runs after the splash clears, on the user's first arrival here.
  Future<void> _maybeStartTour() async {
    final userId = _vm.session.user.id;
    if (!await shouldShowOnboardingTour(userId)) return;
    if (!mounted) return;
    setState(() => _showTour = true);
  }

  HomeViewModel get _vm => context.read<HomeViewModel>();

  Color _transactionColor(FinancialTransactionType type) {
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

  void _handleNavSelection(int index) {
    if (index == _selectedNavIndex) return;

    setState(() {
      _selectedNavIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _showPeriodPicker() {
    if (_vm.visionMode == VisionMode.yearly) {
      _showYearPicker();
    } else {
      _showMonthPicker();
    }
  }

  void _showMonthPicker() {
    final parts = _vm.selectedMonth.split('-');
    var pickerYear = int.tryParse(parts.first) ?? DateTime.now().year;
    var pickerMonth = int.tryParse(parts.last) ?? DateTime.now().month;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return RepaintBoundary(
              child: MonthPickerSheet(
                initialYear: pickerYear,
                initialMonth: pickerMonth,
                onChanged: (year, month) {
                  pickerYear = year;
                  pickerMonth = month;
                },
                onConfirm: () {
                  Navigator.of(context).pop();
                  _vm.setMonth(pickerYear, pickerMonth);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showYearPicker() {
    var pickerYear = int.parse(_vm.selectedYear);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return RepaintBoundary(
              child: YearPickerSheet(
                selectedYear: pickerYear,
                onChanged: (year) {
                  pickerYear = year;
                },
                onConfirm: () {
                  Navigator.of(context).pop();
                  _vm.setYear(pickerYear);
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateTransactionSheet() async {
    final vm = _vm;
    final cards = await vm.cardsFuture ?? const [];
    if (!mounted) return;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RepaintBoundary(
          child: TransactionComposerSheet(
            cards: cards,
            spentByCardId: vm.spentByCardId,
            onSubmit: (transaction, {scope}) async {
              await vm.createTransaction(transaction);
            },
          ),
        );
      },
    );

    if (created == true && mounted) {
      vm.refreshDashboard();
      vm.loadCardSpendTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo com sucesso.')),
      );
    }
  }

  Future<void> _openAddCardSheet() async {
    final vm = _vm;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RepaintBoundary(
          child: CardComposerSheet(
            onSubmit: (card) async {
              await vm.addCard(card);
            },
          ),
        );
      },
    );

    if (result != null && mounted) {
      vm.loadCards();
      vm.cardsRefreshTrigger.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cartão salvo com sucesso.')),
      );
    }
  }

  Future<void> _handleDelete(String id) async {
    final tx = _vm.cachedDashboard?.transactions
        .where((t) => t.id == id)
        .firstOrNull;

    String? scope;
    if (tx?.installmentsTotal != null) {
      final confirmed = await showInstallmentDeleteConfirmDialog(context);
      if (!confirmed || !mounted) return;
    } else if (tx?.isRecurring ?? false) {
      scope = await showRecurringDeleteScopeDialog(context);
      if (scope == null || !mounted) return;
    } else {
      final confirmed = await showDeleteConfirmDialog(context);
      if (!confirmed || !mounted) return;
    }

    try {
      await _vm.deleteTransaction(id, scope: scope);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover lançamento. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          session: _vm.session,
          themeController: _vm.themeController,
        ),
      ),
    );

    if (mounted) {
      await _vm.refreshResolvedAvatarUrl();
    }
  }

  Future<void> _openEditTransactionSheet(FinancialTransaction tx) async {
    final vm = _vm;
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
      vm.loadCardSpendTransactions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento atualizado com sucesso.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final firstName = vm.firstName;
    final profileInitials = vm.profileInitials;
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final topPadding = mediaQuery.padding.top;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const FinanceBackground(),
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedNavIndex = index;
              });
            },
            children: [
              RepaintBoundary(
                child: RefreshIndicator(
                  onRefresh: () async => vm.refreshDashboard(),
                  color: colorScheme.secondary,
                  child: FutureBuilder<FinancialDashboard>(
                    future: vm.dashboardFuture,
                    builder: (context, snapshot) {
                      final error = snapshot.error;
                      final dashboard = vm.cachedDashboard ?? snapshot.data;

                      if (error != null && dashboard == null) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            topPadding + 72,
                            24,
                            bottomPadding + 150,
                          ),
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 56,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Não foi possível carregar o painel.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: vm.refreshDashboard,
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        );
                      }

                      // While loading, the full-screen HomeSplashOverlay
                      // covers this — nothing meaningful to paint yet.
                      if (dashboard == null) {
                        return const SizedBox.shrink();
                      }

                      final topTransactions = dashboard.transactions
                          .take(4)
                          .toList();
                      final categorySummaries = buildCategorySummaries(
                        dashboard.transactions,
                      );
                      final netColor = dashboard.summary.balance >= 0
                          ? colorScheme.tertiary
                          : colorScheme.error;

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          20,
                          topPadding + 18,
                          20,
                          bottomPadding + 174,
                        ),
                        children: [
                          AnimatedSection(
                            order: 0,
                            child: KeyedSubtree(
                              key: _tourTargets.identity,
                              child: TopIdentityBar(
                                firstName: firstName,
                                avatarUrl: vm.resolvedAvatarUrl,
                                profileInitials: profileInitials,
                                isResolvingAvatar: vm.isResolvingAvatar,
                                onProfile: _openSettings,
                                onSignOut: () async {
                                  await Supabase.instance.client.auth.signOut();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AnimatedSection(
                            order: 1,
                            child: KeyedSubtree(
                              key: _tourTargets.period,
                              child: PeriodAndVisionRow(
                                label: vm.visionMode == VisionMode.yearly
                                    ? vm.selectedYear
                                    : formatMonthLabel(vm.selectedMonth),
                                isYearly: vm.visionMode == VisionMode.yearly,
                                onToggleVision: vm.toggleVisionMode,
                                onPrevious: vm.goToPreviousPeriod,
                                onNext: vm.goToNextPeriod,
                                onTapPeriod: _showPeriodPicker,
                                showTodayButton: !vm.isCurrentPeriod,
                                onTapToday: vm.goToCurrentPeriod,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSection(
                            order: 2,
                            child: KeyedSubtree(
                              key: _tourTargets.stats,
                              child: StatCardsScroller(
                                cards: [
                                  FinanceStatCard(
                                    title: 'Entradas',
                                    value: formatCurrency(
                                      dashboard.summary.income,
                                    ),
                                    subtitle:
                                        '${dashboard.summary.entriesCount} registros',
                                    icon: Icons.arrow_upward_rounded,
                                    color: colorScheme.tertiary,
                                  ),
                                  FinanceStatCard(
                                    title: 'Saídas',
                                    value: formatCurrency(
                                      dashboard.summary.expense,
                                    ),
                                    subtitle:
                                        '${dashboard.summary.exitsCount} registros',
                                    icon: Icons.arrow_downward_rounded,
                                    color: colorScheme.error,
                                  ),
                                  FinanceStatCard(
                                    title: 'Saldo',
                                    value: formatCurrency(
                                      dashboard.summary.balance,
                                    ),
                                    subtitle: dashboard.summary.balance < 0
                                        ? '${formatCurrency(dashboard.summary.balance.abs())} negativo'
                                        : '${dashboard.transactions.length} movimentações',
                                    subtitleIcon: dashboard.summary.balance < 0
                                        ? Icons.warning_amber_rounded
                                        : Icons.trending_up_rounded,
                                    icon: dashboard.summary.balance < 0
                                        ? Icons.error_outline_rounded
                                        : Icons.account_balance_wallet_rounded,
                                    color: netColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          AnimatedSection(
                            order: 3,
                            child: KeyedSubtree(
                              key: _tourTargets.bestCard,
                              child: FutureBuilder<List<CreditCard>>(
                                future: vm.cardsFuture,
                                builder: (context, snapshot) {
                                  return SmartCardRecommendation(
                                    cards: snapshot.data ?? const [],
                                    spentByCardId: vm.spentByCardId,
                                    onViewCards: () => _handleNavSelection(2),
                                    onAddCard: _openAddCardSheet,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSection(
                            order: 4,
                            child: KeyedSubtree(
                              key: _tourTargets.categories,
                              child: CategoryBreakdownCard(
                                summaries: categorySummaries,
                                total: dashboard.summary.expense.abs(),
                                formatCurrency: formatCurrency,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSection(
                            order: 5,
                            child: KeyedSubtree(
                              key: _tourTargets.recent,
                              child: topTransactions.isEmpty
                                  ? EmptyStateCard(
                                      onCreate: _openCreateTransactionSheet,
                                    )
                                  : RecentTransactionsCard(
                                      transactions: topTransactions,
                                      formatCurrency: formatCurrency,
                                      formatDate: formatDate,
                                      transactionColor: (transaction) =>
                                          _transactionColor(transaction.type),
                                      transactionIcon: _transactionIcon,
                                      onDelete: _handleDelete,
                                      onViewAll: () => _handleNavSelection(1),
                                      onViewTransaction: (tx) =>
                                          _openEditTransactionSheet(tx),
                                      deletingIds: vm.deletingIds,
                                      removingIds: vm.removingIds,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSection(
                            order: 6,
                            child: KeyedSubtree(
                              key: _tourTargets.insight,
                              child: AiInsightCard(
                                categorySummaries: categorySummaries,
                                summary: dashboard.summary,
                                formatCurrency: formatCurrency,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const TransactionsListPage(),
              CardsPage(
                apiService: vm.cardsApiService,
                refreshTrigger: vm.cardsRefreshTrigger,
                onCardsChanged: vm.loadCards,
                spentByCardId: vm.spentByCardId,
              ),
              ChatPage(
                apiService: vm.chatApiService,
                // The assistant writes through the same API the forms use, so
                // a reload is all it takes for the dashboard and the list
                // (which reads vm.cachedDashboard) to show what it changed.
                onDataChanged: () {
                  vm.refreshDashboard();
                  vm.loadCardSpendTransactions();
                },
              ),
              SettingsPage(
                session: vm.session,
                themeController: vm.themeController,
              ),
            ],
          ),
          if (_selectedNavIndex == 1 || _selectedNavIndex == 2)
            Positioned(
              right: 22,
              bottom: bottomPadding + 92,
              child: KeyedSubtree(
                key: _tourTargets.createButton,
                child: FloatingCreateButton(
                  key: ValueKey(_selectedNavIndex),
                  onPressed: _selectedNavIndex == 1
                      ? _openCreateTransactionSheet
                      : _openAddCardSheet,
                  semanticLabel: _selectedNavIndex == 1
                      ? 'Novo lançamento'
                      : 'Novo cartão',
                ),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottomPadding + 12,
            child: FloatingBottomBar(
              itemKeys: _tourTargets.nav,
              pageController: _pageController,
              selectedIndex: _selectedNavIndex,
              onSelected: _handleNavSelection,
            ),
          ),
          HomeSplashOverlay(ready: _initialLoad, onDismissed: _maybeStartTour),
          if (_showTour)
            Positioned.fill(
              child: OnboardingTour(
                userId: vm.session.user.id,
                firstName: firstName,
                targets: _tourTargets,
                onGoToPage: _handleNavSelection,
                onFinish: () => setState(() => _showTour = false),
              ),
            ),
        ],
      ),
    );
  }
}
