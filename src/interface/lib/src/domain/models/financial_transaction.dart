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
  final String createdAt;
  final String updatedAt;

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
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
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
