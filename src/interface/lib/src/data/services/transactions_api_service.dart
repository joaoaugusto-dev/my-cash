import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:my_cash/src/domain/models/financial_transaction.dart';

class TransactionsApiService {
  TransactionsApiService({
    required this.apiBaseUrl,
    required this.accessTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final FutureOr<String> Function() accessTokenProvider;
  final http.Client _client;

  Future<FinancialDashboard> fetchDashboard({
    String? month,
    String? year,
  }) async {
    final queryParams = <String, String>{};
    if (year != null) {
      queryParams['year'] = year;
    } else {
      queryParams['month'] = month ?? _currentMonth();
    }
    final queryString = Uri(queryParameters: queryParams).query;
    final responses = await Future.wait([
      _getJson('/transactions/summary?$queryString'),
      _getJson('/transactions?$queryString'),
    ]);

    return FinancialDashboard.fromJson(
      summaryJson: responses[0] as Map<String, dynamic>,
      transactionsJson: responses[1] as List<dynamic>,
    );
  }

  Future<FinancialTransaction> createTransaction(
    FinancialTransaction transaction,
  ) async {
    final response = await _client.post(
      _uri('/transactions'),
      headers: await _headers(),
      body: jsonEncode(transaction.toCreateJson()),
    );

    _ensureSuccess(response);
    return FinancialTransaction.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// [scope] matters only when editing a recurring occurrence: 'this' (the
  /// default) splits off just that month as a standalone transaction, past
  /// months untouched; 'forward' splits the series from that month on.
  Future<FinancialTransaction> updateTransaction(
    String id,
    FinancialTransaction transaction, {
    String? scope,
  }) async {
    final query = scope != null ? '?scope=$scope' : '';
    final response = await _client.patch(
      _uri('/transactions/${Uri.encodeComponent(id)}$query'),
      headers: await _headers(),
      body: jsonEncode(transaction.toCreateJson()),
    );

    _ensureSuccess(response);
    return FinancialTransaction.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// [scope] matters only for a recurring occurrence's id: 'this' skips just
  /// that month, 'forward' stops the series from that month on.
  Future<void> deleteTransaction(String id, {String? scope}) async {
    final query = scope != null ? '?scope=$scope' : '';
    final response = await _client.delete(
      _uri('/transactions/${Uri.encodeComponent(id)}$query'),
      headers: await _headers(),
    );

    _ensureSuccess(response);
  }

  Future<dynamic> _getJson(String path) async {
    final response = await _client.get(_uri(path), headers: await _headers());
    _ensureSuccess(response);
    return jsonDecode(response.body);
  }

  Uri _uri(String path) {
    final normalizedBaseUrl = apiBaseUrl.endsWith('/')
        ? apiBaseUrl
        : '$apiBaseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBaseUrl).resolve(normalizedPath);
  }

  Future<Map<String, String>> _headers() async {
    final accessToken = (await accessTokenProvider()).trim();
    if (accessToken.isEmpty) {
      throw StateError('Sessão expirada. Faça login novamente.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'Falha na requisição (${response.statusCode}). Tente novamente.',
    );
  }

  String _currentMonth() {
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }
}
