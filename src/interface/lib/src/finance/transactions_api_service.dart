import 'dart:convert';

import 'package:http/http.dart' as http;

import 'financial_transaction.dart';

class TransactionsApiService {
  TransactionsApiService({
    required this.apiBaseUrl,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final String accessToken;
  final http.Client _client;

  Future<FinancialDashboard> fetchDashboard({String? month}) async {
    final monthFilter = month ?? _currentMonth();
    final responses = await Future.wait([
      _getJson('/transactions/summary?month=$monthFilter'),
      _getJson('/transactions?month=$monthFilter'),
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
      headers: _headers,
      body: jsonEncode(transaction.toCreateJson()),
    );

    _ensureSuccess(response);
    return FinancialTransaction.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final response = await _client.delete(
      _uri('/transactions/$id'),
      headers: _headers,
    );

    _ensureSuccess(response);
  }

  Future<dynamic> _getJson(String path) async {
    final response = await _client.get(_uri(path), headers: _headers);
    _ensureSuccess(response);
    return jsonDecode(response.body);
  }

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw http.ClientException(
      'Request failed (${response.statusCode}): ${response.body}',
      response.request?.url,
    );
  }

  String _currentMonth() {
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }
}
