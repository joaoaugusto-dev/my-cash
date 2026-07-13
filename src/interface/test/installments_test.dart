import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/domain/models/installments.dart';

void main() {
  test('returns the total unchanged for a single installment', () {
    expect(splitIntoInstallments(150.0, 1), [150.0]);
  });

  test('splits evenly when the total divides cleanly', () {
    expect(splitIntoInstallments(300.0, 3), [100.0, 100.0, 100.0]);
  });

  test('puts the rounding remainder on the last installment', () {
    final installments = splitIntoInstallments(100.0, 3);
    expect(installments, [33.33, 33.33, 33.34]);
    expect(installments.reduce((a, b) => a + b), 100.0);
  });
}
