import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_cash/src/utils/profile_helpers.dart';
import 'package:my_cash/src/data/services/session_access_token_provider.dart';
import 'package:my_cash/src/config/app_env.dart';
import 'package:my_cash/src/data/services/cards_api_service.dart';
import 'package:my_cash/src/data/services/chat_api_service.dart';
import 'package:my_cash/src/domain/models/credit_card.dart';
import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/data/services/transactions_api_service.dart';
import 'package:my_cash/src/ui/core/theme/app_theme_controller.dart';
import '../../../utils/formatters.dart';

enum VisionMode { monthly, yearly }

/// Holds all dashboard state and business logic for the home screen.
/// The View (home_screen.dart) only renders and forwards user intent here.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this.session, required this.themeController});

  final Session session;
  final AppThemeController themeController;

  static const String _avatarBucket = 'avatars';

  late final TransactionsApiService apiService;
  late final CardsApiService cardsApiService;
  late final ChatApiService chatApiService;
  late final SessionAccessTokenProvider _accessTokenProvider;
  late final Future<SharedPreferences> _preferencesFuture;

  Future<FinancialDashboard>? dashboardFuture;
  FinancialDashboard? cachedDashboard;
  Future<List<CreditCard>>? cardsFuture;
  List<FinancialTransaction> _cardSpendTransactions = const [];

  String resolvedAvatarUrl = '';
  String _avatarStateKey = '';
  bool isResolvingAvatar = false;

  VisionMode visionMode = VisionMode.monthly;
  String selectedMonth = currentMonth();
  String selectedYear = DateTime.now().year.toString();

  final Set<String> deletingIds = {};
  final Set<String> removingIds = {};
  final ValueNotifier<int> cardsRefreshTrigger = ValueNotifier<int>(0);

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void init() {
    _preferencesFuture = SharedPreferences.getInstance();
    final auth = Supabase.instance.client.auth;
    _accessTokenProvider = SessionAccessTokenProvider(
      currentSessionProvider: () => auth.currentSession,
      refreshSession: auth.refreshSession,
    );
    apiService = TransactionsApiService(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessTokenProvider: _accessTokenProvider.call,
    );
    cardsApiService = CardsApiService(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessTokenProvider: _accessTokenProvider.call,
    );
    chatApiService = ChatApiService(
      apiBaseUrl: AppEnv.apiBaseUrl,
      accessTokenProvider: _accessTokenProvider.call,
    );
    dashboardFuture = loadDashboard();
    cardsFuture = cardsApiService.fetchCards();
    loadCardSpendTransactions();
    refreshResolvedAvatarUrl();
  }

  /// Current month's transactions, used only to estimate card usage —
  /// independent of whatever period the dashboard above is currently showing.
  void loadCardSpendTransactions() {
    apiService.fetchDashboard(month: currentMonth()).then((dashboard) {
      _cardSpendTransactions = dashboard.transactions;
      _notify();
    });
  }

  /// Estimated amount spent so far this month per card id.
  /// Approximates the invoice by calendar month rather than each card's
  /// exact closing-day cycle — good enough for an at-a-glance estimate.
  Map<String, double> get spentByCardId {
    final totals = <String, double>{};
    for (final transaction in _cardSpendTransactions) {
      final cardId = transaction.cardId;
      if (cardId == null ||
          transaction.type != FinancialTransactionType.expense) {
        continue;
      }
      totals[cardId] = (totals[cardId] ?? 0) + transaction.amount;
    }
    return totals;
  }

  void loadCards() {
    cardsFuture = cardsApiService.fetchCards();
    _notify();
    loadCardSpendTransactions();
  }

  Future<FinancialDashboard> loadDashboard() {
    final future = visionMode == VisionMode.yearly
        ? apiService.fetchDashboard(year: selectedYear)
        : apiService.fetchDashboard(month: selectedMonth);
    return future.then((data) {
      cachedDashboard = data;
      _notify();
      return data;
    });
  }

  void refreshDashboard() {
    dashboardFuture = loadDashboard();
    _notify();
  }

  void toggleVisionMode() {
    visionMode = visionMode == VisionMode.monthly
        ? VisionMode.yearly
        : VisionMode.monthly;
    refreshDashboard();
  }

  void setMonth(int year, int month) {
    selectedMonth = '$year-${month.toString().padLeft(2, '0')}';
    refreshDashboard();
  }

  void setYear(int year) {
    selectedYear = year.toString();
    refreshDashboard();
  }

  /// Whether the selected period is the current month/year — used to show a
  /// "back to today" shortcut once the user has navigated away from it.
  bool get isCurrentPeriod => visionMode == VisionMode.yearly
      ? selectedYear == DateTime.now().year.toString()
      : selectedMonth == currentMonth();

  void goToCurrentPeriod() {
    if (isCurrentPeriod) return;
    if (visionMode == VisionMode.yearly) {
      selectedYear = DateTime.now().year.toString();
    } else {
      selectedMonth = currentMonth();
    }
    refreshDashboard();
  }

  void goToPreviousPeriod() {
    if (visionMode == VisionMode.yearly) {
      final year = int.parse(selectedYear);
      selectedYear = (year - 1).toString();
    } else {
      final date = DateTime.parse('$selectedMonth-01');
      final prev = DateTime(date.year, date.month - 1, 1);
      selectedMonth = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    }
    refreshDashboard();
  }

  void goToNextPeriod() {
    if (visionMode == VisionMode.yearly) {
      final year = int.parse(selectedYear);
      selectedYear = (year + 1).toString();
    } else {
      final date = DateTime.parse('$selectedMonth-01');
      final next = DateTime(date.year, date.month + 1, 1);
      selectedMonth = '${next.year}-${next.month.toString().padLeft(2, '0')}';
    }
    refreshDashboard();
  }

  Future<void> createTransaction(FinancialTransaction transaction) {
    return apiService.createTransaction(transaction);
  }

  Future<void> updateTransaction(
    FinancialTransaction transaction, {
    String? scope,
  }) {
    return apiService.updateTransaction(
      transaction.id,
      transaction,
      scope: scope,
    );
  }

  Future<void> addCard(CreditCard card) {
    return cardsApiService.createCard(card);
  }

  Future<void> deleteTransaction(String id, {String? scope}) async {
    if (deletingIds.contains(id) || removingIds.contains(id)) return;
    deletingIds.add(id);
    _notify();
    try {
      await apiService.deleteTransaction(id, scope: scope);
      if (_disposed) return;
      deletingIds.remove(id);
      removingIds.add(id);
      _notify();
      await Future.delayed(const Duration(milliseconds: 350));
      if (_disposed) return;
      final dashboard = cachedDashboard;
      if (dashboard != null) {
        final tx = dashboard.transactions.where((t) => t.id == id).firstOrNull;
        final updatedTx = dashboard.transactions
            .where((t) => t.id != id)
            .toList();
        final amount = tx?.amount ?? 0;
        final isIncome = tx?.type == FinancialTransactionType.income;
        cachedDashboard = FinancialDashboard(
          summary: TransactionSummary(
            month: dashboard.summary.month,
            income: dashboard.summary.income - (isIncome ? amount : 0),
            expense: dashboard.summary.expense - (isIncome ? 0 : amount),
            balance:
                dashboard.summary.balance -
                (isIncome ? amount : 0) +
                (isIncome ? 0 : amount),
            entriesCount: dashboard.summary.entriesCount - (isIncome ? 1 : 0),
            exitsCount: dashboard.summary.exitsCount - (isIncome ? 0 : 1),
          ),
          transactions: updatedTx,
        );
        removingIds.remove(id);
        _notify();
      }
    } catch (_) {
      if (_disposed) return;
      deletingIds.remove(id);
      _notify();
      rethrow;
    }
  }

  Future<void> refreshResolvedAvatarUrl() async {
    final user = Supabase.instance.client.auth.currentUser ?? session.user;
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
    isResolvingAvatar = true;
    _notify();

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

    if (_disposed) return;
    resolvedAvatarUrl = resolvedUrl;
    isResolvingAvatar = false;
    _notify();
  }

  String get firstName {
    final user = Supabase.instance.client.auth.currentUser ?? session.user;
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

  String get profileInitials {
    final user = Supabase.instance.client.auth.currentUser ?? session.user;
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final fullName = (metadata['full_name'] ?? metadata['name'] ?? '')
        .toString()
        .trim();
    return initialsFromProfile(fullName: fullName, email: user.email ?? '');
  }

  @override
  void dispose() {
    _disposed = true;
    cardsRefreshTrigger.dispose();
    super.dispose();
  }
}
