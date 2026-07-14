class CreditCard {
  CreditCard({
    required this.id,
    required this.userId,
    required this.name,
    required this.brand,
    required this.lastDigits,
    required this.limitAmount,
    required this.closingDay,
    required this.createdAt,
    required this.updatedAt,
    this.color = '#6D28D9',
  });

  final String id;
  final String userId;
  final String name;
  final String brand;
  final String lastDigits;
  final double limitAmount;
  final int closingDay;
  final String createdAt;
  final String updatedAt;

  /// Hex color the user picked for the card face, independent of [brand].
  final String color;

  factory CreditCard.fromJson(Map<String, dynamic> json) {
    return CreditCard(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String,
      lastDigits: json['lastDigits'] as String,
      limitAmount: (json['limitAmount'] as num).toDouble(),
      closingDay: (json['closingDay'] as num).toInt(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      color: json['color'] as String? ?? '#6D28D9',
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'brand': brand,
      'lastDigits': lastDigits,
      'limitAmount': limitAmount,
      'closingDay': closingDay,
      'color': color,
    };
  }
}
