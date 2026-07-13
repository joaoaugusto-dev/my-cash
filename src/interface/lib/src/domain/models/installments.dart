/// Splits [total] into [count] cents-rounded installments that sum back to
/// the original total exactly — the rounding remainder lands on the last one.
List<double> splitIntoInstallments(double total, int count) {
  if (count <= 1) return [total];

  final perInstallment = _roundToCents(total / count);
  final last = _roundToCents(total - perInstallment * (count - 1));
  return [for (var i = 0; i < count - 1; i++) perInstallment, last];
}

double _roundToCents(double value) => (value * 100).round() / 100;
