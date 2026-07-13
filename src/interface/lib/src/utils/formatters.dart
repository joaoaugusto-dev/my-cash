// Pure formatting helpers shared across the UI (no Flutter dependency).

String formatCurrency(double value) {
  final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $absolute';
}

String formatDate(String isoDate) {
  final date = DateTime.tryParse(isoDate)?.toLocal();
  if (date == null) {
    return isoDate;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

const _monthNames = [
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

String formatMonthLabel(String month) {
  final parts = month.split('-');
  if (parts.length < 2) {
    return month;
  }

  final parsedMonth = int.tryParse(parts[1]);
  final year = parts.first;

  if (parsedMonth == null || parsedMonth < 1 || parsedMonth > 12) {
    return parts.first;
  }

  return '${_monthNames[parsedMonth - 1]} $year';
}

/// Current UTC month as `YYYY-MM`.
String currentMonth() {
  final now = DateTime.now().toUtc();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
}
