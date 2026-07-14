enum FinancialTransactionType { income, expense }

class FinancialTransaction {
  FinancialTransaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.source,
    this.cardId,
    this.seriesId,
    this.recurrenceFrequency,
    this.recurrenceInterval,
    this.recurrenceUnit,
    this.installmentsTotal,
  });

  final String id;
  final String userId;
  final String title;
  final double amount;
  final FinancialTransactionType type;
  final String category;
  final String occurredAt;
  final String? notes;
  final String? source;
  final String? cardId;
  final String createdAt;
  final String updatedAt;

  /// Set only on virtual occurrences of a recurring series (matches the
  /// anchor transaction's real id); null for one-off transactions.
  final String? seriesId;
  final String? recurrenceFrequency;
  final int? recurrenceInterval;
  final String? recurrenceUnit;

  /// Total parcelas for an installment purchase; set on both the anchor and
  /// every occurrence expanded from it.
  final int? installmentsTotal;

  bool get isRecurring => seriesId != null || recurrenceFrequency != null;

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    return FinancialTransaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: _parseType(json['type'] as String),
      category: json['category'] as String,
      occurredAt: json['occurredAt'] as String,
      notes: json['notes'] as String?,
      source: json['source'] as String?,
      cardId: json['cardId'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      seriesId: json['seriesId'] as String?,
      recurrenceFrequency: json['recurrenceFrequency'] as String?,
      recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt(),
      recurrenceUnit: json['recurrenceUnit'] as String?,
      installmentsTotal: (json['installmentsTotal'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'occurredAt': occurredAt,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
      if (source != null && source!.trim().isNotEmpty) 'source': source,
      if (cardId != null) 'cardId': cardId,
      if (installmentsTotal != null) 'installmentsTotal': installmentsTotal,
      // Always sent (even as null) so editing can explicitly clear recurrence —
      // omitting the key would make the backend leave the old value untouched.
      'recurrenceFrequency': recurrenceFrequency,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceUnit': recurrenceUnit,
    };
  }

  static FinancialTransactionType _parseType(String value) {
    return switch (value) {
      'income' => FinancialTransactionType.income,
      'expense' => FinancialTransactionType.expense,
      _ => FinancialTransactionType.expense,
    };
  }
}

class TransactionSummary {
  TransactionSummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
    required this.entriesCount,
    required this.exitsCount,
  });

  final String month;
  final double income;
  final double expense;
  final double balance;
  final int entriesCount;
  final int exitsCount;

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      month: json['month'] as String,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      entriesCount: (json['entriesCount'] as num).toInt(),
      exitsCount: (json['exitsCount'] as num).toInt(),
    );
  }
}

class FinancialDashboard {
  FinancialDashboard({required this.summary, required this.transactions});

  final TransactionSummary summary;
  final List<FinancialTransaction> transactions;

  factory FinancialDashboard.fromJson({
    required Map<String, dynamic> summaryJson,
    required List<dynamic> transactionsJson,
  }) {
    return FinancialDashboard(
      summary: TransactionSummary.fromJson(summaryJson),
      transactions: transactionsJson
          .map(
            (item) =>
                FinancialTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
