import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';
import '../finance/financial_transaction.dart';
import '../finance/transactions_api_service.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/finance_stat_card.dart';
import 'profile_helpers.dart';
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
  static const String _avatarBucket = 'avatars';

  late final TransactionsApiService _apiService;
  late final Future<SharedPreferences> _preferencesFuture;
  Future<FinancialDashboard>? _dashboardFuture;
  String _resolvedAvatarUrl = '';
  String _avatarStateKey = '';
  int _selectedNavIndex = 0;
  bool _isResolvingAvatar = false;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = SharedPreferences.getInstance();
    _apiService = TransactionsApiService(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessTokenProvider: _currentAccessToken,
    );
    _dashboardFuture = _loadDashboard();
    _refreshResolvedAvatarUrl();
  }

  Future<FinancialDashboard> _loadDashboard() {
    return _apiService.fetchDashboard();
  }

  String _currentAccessToken() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    return session.accessToken;
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

  String _formatMonthLabel(String month) {
    final parts = month.split('-');
    if (parts.length < 2) {
      return month;
    }

    final parsedMonth = int.tryParse(parts[1]);
    final year = parts.first;
    const monthNames = [
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

    if (parsedMonth == null || parsedMonth < 1 || parsedMonth > 12) {
      return month;
    }

    return '${monthNames[parsedMonth - 1]} $year';
  }

  List<_CategorySummary> _categorySummaries(
    BuildContext context,
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
        _CategorySummary(
          name: visibleEntries[index].key,
          amount: visibleEntries[index].value,
          percent: totalExpense <= 0
              ? 0
              : visibleEntries[index].value / totalExpense,
          icon: _categoryIcon(visibleEntries[index].key),
          color: _categoryColor(index),
        ),
    ];
  }

  IconData _categoryIcon(String category) {
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

  Color _categoryColor(int index) {
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
      await _refreshResolvedAvatarUrl();
    }
  }

  void _handleNavSelection(int index) {
    if (index == 0) {
      setState(() {
        _selectedNavIndex = 0;
      });
      return;
    }

    if (index == 4) {
      setState(() {
        _selectedNavIndex = index;
      });
      _openSettings().whenComplete(() {
        if (mounted) {
          setState(() {
            _selectedNavIndex = 0;
          });
        }
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Essa área entra na próxima etapa.')),
    );
  }

  String _extractFirstName() {
    final user =
        Supabase.instance.client.auth.currentUser ?? widget.session.user;
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final fullName = (metadata['full_name'] ?? metadata['name'] ?? '')
        .toString()
        .trim();

    if (fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
        return parts.first.trim();
      }
    }

    return 'Conta';
  }

  String _profileInitials() {
    final user =
        Supabase.instance.client.auth.currentUser ?? widget.session.user;
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final fullName = (metadata['full_name'] ?? metadata['name'] ?? '')
        .toString()
        .trim();
    return initialsFromProfile(fullName: fullName, email: user.email ?? '');
  }

  Future<void> _refreshResolvedAvatarUrl() async {
    final user =
        Supabase.instance.client.auth.currentUser ?? widget.session.user;
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final avatarUrl = extractAvatarUrl(metadata);
    final avatarPath = extractAvatarPath(metadata);
    final avatarVersion = extractAvatarVersion(metadata);

    final cacheIdentity = buildAvatarCacheIdentity(
      userId: user.id,
      avatarPath: avatarPath,
      avatarUrl: avatarUrl,
      avatarVersion: avatarVersion,
    );
    if (cacheIdentity == _avatarStateKey) {
      return;
    }

    _avatarStateKey = cacheIdentity;
    if (mounted) {
      setState(() {
        _isResolvingAvatar = true;
      });
    }

    String resolvedUrl = '';
    try {
      final prefs = await _preferencesFuture;
      final cachedUrl = await readCachedAvatarUrl(
        prefs: prefs,
        userId: user.id,
        identity: cacheIdentity,
      );
      if (cachedUrl != null) {
        resolvedUrl = cachedUrl;
      } else if ((avatarPath ?? '').isNotEmpty) {
        final signedUrl = await Supabase.instance.client.storage
            .from(_avatarBucket)
            .createSignedUrl(avatarPath!, 60 * 60 * 24);
        resolvedUrl = buildAvatarCacheAwareUrl(signedUrl, avatarVersion);
        await writeCachedAvatarUrl(
          prefs: prefs,
          userId: user.id,
          identity: cacheIdentity,
          avatarUrl: resolvedUrl,
          expiresAt: DateTime.now().toUtc().add(avatarSignedUrlCacheDuration),
        );
      } else {
        resolvedUrl = buildAvatarCacheAwareUrl(avatarUrl, avatarVersion);
        await writeCachedAvatarUrl(
          prefs: prefs,
          userId: user.id,
          identity: cacheIdentity,
          avatarUrl: resolvedUrl,
          expiresAt: DateTime.now().toUtc().add(avatarSignedUrlCacheDuration),
        );
      }
    } catch (_) {
      resolvedUrl = buildAvatarCacheAwareUrl(avatarUrl, avatarVersion);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _resolvedAvatarUrl = resolvedUrl;
      _isResolvingAvatar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _extractFirstName();
    final profileInitials = _profileInitials();
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final topPadding = mediaQuery.padding.top;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _FinanceBackground(),
          RefreshIndicator(
            onRefresh: () async => _refreshDashboard(),
            color: colorScheme.secondary,
            child: FutureBuilder<FinancialDashboard>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final error = snapshot.error;
                final dashboard = snapshot.data;

                if (error != null) {
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
                        onPressed: _refreshDashboard,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  );
                }

                if (isLoading || dashboard == null) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      topPadding + 92,
                      24,
                      bottomPadding + 150,
                    ),
                    children: const [_DashboardLoadingCard()],
                  );
                }

                final topTransactions = dashboard.transactions.take(4).toList();
                final categorySummaries = _categorySummaries(
                  context,
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
                    _AnimatedSection(
                      order: 0,
                      child: _TopIdentityBar(
                        firstName: firstName,
                        avatarUrl: _resolvedAvatarUrl,
                        profileInitials: profileInitials,
                        isResolvingAvatar: _isResolvingAvatar,
                        onProfile: _openSettings,
                        onSignOut: () async {
                          await Supabase.instance.client.auth.signOut();
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    _AnimatedSection(
                      order: 1,
                      child: _PeriodAndVisionRow(
                        month: _formatMonthLabel(dashboard.summary.month),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AnimatedSection(
                      order: 2,
                      child: _StatCardsScroller(
                        cards: [
                          FinanceStatCard(
                            title: 'Entradas',
                            value: _formatCurrency(dashboard.summary.income),
                            subtitle:
                                '${dashboard.summary.entriesCount} registros',
                            icon: Icons.arrow_upward_rounded,
                            color: colorScheme.tertiary,
                          ),
                          FinanceStatCard(
                            title: 'Saídas',
                            value: _formatCurrency(dashboard.summary.expense),
                            subtitle:
                                '${dashboard.summary.exitsCount} registros',
                            icon: Icons.arrow_downward_rounded,
                            color: colorScheme.error,
                          ),
                          FinanceStatCard(
                            title: 'Saldo',
                            value: _formatCurrency(dashboard.summary.balance),
                            subtitle:
                                '${dashboard.transactions.length} movimentações',
                            icon: Icons.account_balance_wallet_rounded,
                            color: netColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _AnimatedSection(
                      order: 3,
                      child: _SmartCardRecommendation(),
                    ),
                    const SizedBox(height: 14),
                    _AnimatedSection(
                      order: 4,
                      child: _CategoryBreakdownCard(
                        summaries: categorySummaries,
                        total: dashboard.summary.expense.abs(),
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AnimatedSection(
                      order: 5,
                      child: topTransactions.isEmpty
                          ? _EmptyStateCard(
                              onCreate: _openCreateTransactionSheet,
                            )
                          : _RecentTransactionsCard(
                              transactions: topTransactions,
                              formatCurrency: _formatCurrency,
                              formatDate: _formatDate,
                              transactionColor: (transaction) =>
                                  _transactionColor(context, transaction.type),
                              transactionIcon: _transactionIcon,
                              onDelete: _deleteTransaction,
                            ),
                    ),
                    const SizedBox(height: 14),
                    _AnimatedSection(
                      order: 6,
                      child: _AiInsightCard(
                        categorySummaries: categorySummaries,
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            right: 22,
            bottom: bottomPadding + 92,
            child: _FloatingCreateButton(
              onPressed: _openCreateTransactionSheet,
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottomPadding + 12,
            child: _FloatingBottomBar(
              selectedIndex: _selectedNavIndex,
              onSelected: _handleNavSelection,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySummary {
  const _CategorySummary({
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

class _FinanceBackground extends StatelessWidget {
  const _FinanceBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF110A22), Color(0xFF1B1230), Color(0xFF0D0B16)]
              : const [Color(0xFFFBFAFF), Color(0xFFF4F0FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -80,
            child: _RadialGlow(
              size: 250,
              color: const Color(
                0xFF7C3AED,
              ).withValues(alpha: isDark ? 0.22 : 0.15),
            ),
          ),
          Positioned(
            top: 130,
            right: -110,
            child: _RadialGlow(
              size: 260,
              color: const Color(
                0xFFB993FF,
              ).withValues(alpha: isDark ? 0.18 : 0.22),
            ),
          ),
          Positioned(
            bottom: -130,
            left: 20,
            child: _RadialGlow(
              size: 280,
              color: const Color(
                0xFF22C55E,
              ).withValues(alpha: isDark ? 0.10 : 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatefulWidget {
  const _AnimatedSection({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 70 * widget.order), () {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _TopIdentityBar extends StatelessWidget {
  const _TopIdentityBar({
    required this.firstName,
    required this.avatarUrl,
    required this.profileInitials,
    required this.isResolvingAvatar,
    required this.onProfile,
    required this.onSignOut,
  });

  final String firstName;
  final String avatarUrl;
  final String profileInitials;
  final bool isResolvingAvatar;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'MyCash',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Olá, $firstName!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Bem-vindo de volta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          tooltip: 'Perfil',
          offset: const Offset(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (value) {
            if (value == 'profile') {
              onProfile();
            }
            if (value == 'signOut') {
              onSignOut();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'profile', child: Text('Configurações')),
            PopupMenuItem(value: 'signOut', child: Text('Sair')),
          ],
          child: _ProfileAvatar(
            avatarUrl: avatarUrl,
            profileInitials: profileInitials,
            isResolvingAvatar: isResolvingAvatar,
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.profileInitials,
    required this.isResolvingAvatar,
  });

  final String avatarUrl;
  final String profileInitials;
  final bool isResolvingAvatar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.secondary.withValues(alpha: 0.28),
            colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: colorScheme.secondary.withValues(alpha: 0.14),
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: isResolvingAvatar
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.secondary,
                ),
              )
            : avatarUrl.isEmpty
            ? Text(
                profileInitials,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
    );
  }
}

class _PeriodAndVisionRow extends StatelessWidget {
  const _PeriodAndVisionRow({required this.month});

  final String month;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final monthSelector = _PillButton(
          icon: Icons.calendar_month_rounded,
          label: month,
          trailingIcon: Icons.keyboard_arrow_down_rounded,
          isPrimary: true,
        );
        const visionToggle = _VisionToggle();

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [monthSelector, const SizedBox(height: 12), visionToggle],
          );
        }

        return Row(
          children: [
            Expanded(child: monthSelector),
            const SizedBox(width: 14),
            const Expanded(child: visionToggle),
          ],
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.trailingIcon,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final IconData trailingIcon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF5B21B6), Color(0xFF8B2CEB)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: isPrimary ? null : colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPrimary
              ? Colors.white.withValues(alpha: 0.18)
              : colorScheme.outline.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF5B21B6,
            ).withValues(alpha: isPrimary ? 0.22 : 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: isPrimary ? Colors.white : colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isPrimary ? Colors.white : colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(
            trailingIcon,
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.9)
                : colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ],
      ),
    );
  }
}

class _VisionToggle extends StatelessWidget {
  const _VisionToggle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D28D9), Color(0xFF8B2CEB)],
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                'Visão Mensal',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Visão Anual',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardsScroller extends StatelessWidget {
  const _StatCardsScroller({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index != cards.length - 1) const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              cards[index],
              if (index != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            tint ?? colorScheme.surface.withValues(alpha: isDark ? 0.72 : 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SmartCardRecommendation extends StatelessWidget {
  const _SmartCardRecommendation();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SoftPanel(
      padding: const EdgeInsets.all(18),
      tint: colorScheme.secondary.withValues(alpha: 0.07),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          final cardPreview = Container(
            width: isNarrow ? double.infinity : 186,
            height: 126,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6D28D9),
                  Color(0xFF8B2CEB),
                  Color(0xFF4C1D95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'nu',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.credit_card_rounded,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                const SizedBox(height: 8),
                Text(
                  '**** 1234',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '* INTELIGÊNCIA MyCash',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Melhor cartão para hoje',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Nubank Crédito',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Fecha em 05/07. Ideal para compras até o fechamento.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.25,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cardPreview,
                const SizedBox(height: 18),
                copy,
                const SizedBox(height: 14),
                const _LightActionChip(label: 'Ver cartões'),
              ],
            );
          }

          return Row(
            children: [
              cardPreview,
              const SizedBox(width: 20),
              Expanded(child: copy),
              const SizedBox(width: 12),
              const _LightActionChip(label: 'Ver cartões'),
            ],
          );
        },
      ),
    );
  }
}

class _LightActionChip extends StatelessWidget {
  const _LightActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.summaries,
    required this.total,
    required this.formatCurrency,
  });

  final List<_CategorySummary> summaries;
  final double total;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gastos por categoria',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'Ver todas',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (summaries.isEmpty)
            Text(
              'Sem saídas registradas para montar o gráfico deste mês.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final chart = Center(
                  child: RepaintBoundary(
                    child: _DonutChart(
                      summaries: summaries,
                      totalLabel: formatCurrency(total),
                    ),
                  ),
                );
                final list = Column(
                  children: [
                    for (final summary in summaries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _CategoryLegendRow(
                          summary: summary,
                          formatCurrency: formatCurrency,
                        ),
                      ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [chart, const SizedBox(height: 18), list],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 220, child: chart),
                    const SizedBox(width: 18),
                    Expanded(child: list),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.summary,
    required this.formatCurrency,
  });

  final _CategorySummary summary;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: summary.color.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: Icon(summary.icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            summary.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          formatCurrency(summary.amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 42,
          child: Text(
            '${(summary.percent * 100).round()}%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.summaries, required this.totalLabel});

  final List<_CategorySummary> summaries;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 174,
      height: 174,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(174),
            painter: _DonutChartPainter(summaries),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.52),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter(this.summaries);

  final List<_CategorySummary> summaries;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 13;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 31.0;
    var startAngle = -math.pi / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFE7E2F4);
    canvas.drawCircle(center, radius, basePaint);

    for (final summary in summaries) {
      final sweep = math.max(summary.percent * math.pi * 2, 0.02);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = summary.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.summaries != summaries;
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
    required this.transactionColor,
    required this.transactionIcon,
    required this.onDelete,
  });

  final List<FinancialTransaction> transactions;
  final String Function(double value) formatCurrency;
  final String Function(String isoDate) formatDate;
  final Color Function(FinancialTransaction transaction) transactionColor;
  final IconData Function(FinancialTransactionType type) transactionIcon;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SoftPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transações recentes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Ver todas',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < transactions.length; index++) ...[
            _CompactTransactionRow(
              transaction: transactions[index],
              formatCurrency: formatCurrency,
              formatDate: formatDate,
              color: transactionColor(transactions[index]),
              icon: transactionIcon(transactions[index].type),
              onDelete: () => onDelete(transactions[index].id),
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
    final colorScheme = Theme.of(context).colorScheme;
    final sign = transaction.type == FinancialTransactionType.income
        ? '+ '
        : '- ';

    return Padding(
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
          IconButton(
            tooltip: 'Excluir lançamento',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.categorySummaries,
    required this.formatCurrency,
  });

  final List<_CategorySummary> categorySummaries;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topCategory = categorySummaries.isEmpty
        ? null
        : categorySummaries.first;
    final title = topCategory == null
        ? 'Crie lançamentos para liberar insights automáticos.'
        : 'Gastos com ${topCategory.name} lideram este mês.';
    final subtitle = topCategory == null
        ? 'A IA compara padrões quando houver dados suficientes.'
        : 'Você já registrou ${formatCurrency(topCategory.amount)} nessa categoria.';

    return _SoftPanel(
      padding: const EdgeInsets.all(14),
      tint: colorScheme.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_alt_rounded,
              size: 38,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '* Insight da IA',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
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
          Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
        ],
      ),
    );
  }
}

class _FloatingCreateButton extends StatelessWidget {
  const _FloatingCreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Novo lançamento',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B2CEB), Color(0xFF4C1D95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C1D95).withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}

class _FloatingBottomBar extends StatelessWidget {
  const _FloatingBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isVeryNarrow = width < 370;
    final barHeight = isVeryNarrow ? 72.0 : 78.0;
    final horizontalPadding = isVeryNarrow ? 5.0 : 8.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: barHeight,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  5,
                  horizontalPadding,
                  5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(
                    alpha: isDark ? 0.72 : 0.76,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colorScheme.outline.withValues(
                      alpha: isDark ? 0.42 : 0.62,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.09,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _BottomNavItem(
                      index: 0,
                      selectedIndex: selectedIndex,
                      icon: Icons.home_rounded,
                      label: 'Início',
                      compactLabel: 'Início',
                      dense: isVeryNarrow,
                      onSelected: onSelected,
                    ),
                    _BottomNavItem(
                      index: 1,
                      selectedIndex: selectedIndex,
                      icon: Icons.list_alt_rounded,
                      label: 'Transações',
                      compactLabel: 'Trans.',
                      dense: isVeryNarrow,
                      onSelected: onSelected,
                    ),
                    _BottomNavItem(
                      index: 2,
                      selectedIndex: selectedIndex,
                      icon: Icons.credit_card_rounded,
                      label: 'Cartões',
                      compactLabel: 'Cards',
                      dense: isVeryNarrow,
                      onSelected: onSelected,
                    ),
                    _BottomNavItem(
                      index: 3,
                      selectedIndex: selectedIndex,
                      icon: Icons.auto_awesome_rounded,
                      label: 'Chat IA',
                      compactLabel: 'IA',
                      dense: isVeryNarrow,
                      onSelected: onSelected,
                    ),
                    _BottomNavItem(
                      index: 4,
                      selectedIndex: selectedIndex,
                      icon: Icons.person_outline_rounded,
                      label: 'Perfil',
                      compactLabel: 'Perfil',
                      dense: isVeryNarrow,
                      onSelected: onSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.compactLabel,
    required this.dense,
    required this.onSelected,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final String compactLabel;
  final bool dense;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = index == selectedIndex;
    final itemLabel = dense ? compactLabel : label;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: dense ? 4 : 5),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isSelected ? (dense ? 30 : 36) : 18,
                height: 3,
                margin: EdgeInsets.only(bottom: dense ? 5 : 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.secondary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.55),
                size: dense ? 23 : 25,
              ),
              SizedBox(height: dense ? 2 : 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    itemLabel,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.62),
                      fontSize: dense ? 10 : 11,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
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

class _DashboardLoadingCard extends StatelessWidget {
  const _DashboardLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SoftPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.secondary),
          const SizedBox(height: 18),
          Text(
            'Preparando seu painel financeiro...',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
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
              Row(
                children: [
                  IconButton(
                    tooltip: 'Voltar',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Novo lançamento',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
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
