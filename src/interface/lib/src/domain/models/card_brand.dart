import 'package:flutter/material.dart';

enum CardBrand {
  visa('Visa', 'assets/card_flags/visa.svg'),
  mastercard('Mastercard', 'assets/card_flags/mastercard.svg'),
  elo('Elo', 'assets/card_flags/elo.svg'),
  hipercard('Hipercard', 'assets/card_flags/hipercard.svg'),
  amex('American Express', 'assets/card_flags/amex.svg'),
  outra('Outra', null);

  const CardBrand(this.label, this.assetPath);

  final String label;
  final String? assetPath;

  static const List<CardBrand> known = [visa, mastercard, elo, hipercard, amex];

  static CardBrand fromApiValue(String value) {
    return known.firstWhere(
      (brand) => brand.label.toLowerCase() == value.toLowerCase(),
      orElse: () => CardBrand.outra,
    );
  }
}

/// Parses a "#RRGGBB" hex string (as stored/returned by the API) into a [Color].
Color colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '').padLeft(6, '0');
  return Color(int.parse('FF$normalized', radix: 16));
}

/// The card face gradient for a user-chosen [base] color: lightens toward the
/// bottom-right, matching the direction every built-in brand gradient used.
List<Color> cardGradient(Color base) => [base, Color.lerp(base, Colors.white, 0.3)!];
