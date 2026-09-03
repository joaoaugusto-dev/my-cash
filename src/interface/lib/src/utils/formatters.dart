// Pure formatting helpers shared across the UI (no Flutter dependency).

String formatCurrency(double value) {
  final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $absolute';
}

String formatDate(String isoDate) {
  final date = parseCalendarDate(isoDate);
  if (date == null) {
    return isoDate;
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

/// Reads the calendar day an `occurredAt`-style ISO string names, ignoring
/// any time-of-day or timezone offset. These fields mean "this day
/// happened" rather than a precise instant (the backend stores them as UTC
/// midnight) — `DateTime.parse(iso).toLocal()` would shift that midnight
/// into the previous day for any timezone behind UTC, including Brazil's.
DateTime? parseCalendarDate(String isoDate) {
  final datePart = isoDate.split('T').first.split(' ').first;
  final parts = datePart.split('-');
  if (parts.length != 3) {
    return DateTime.tryParse(isoDate);
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return DateTime.tryParse(isoDate);
  }
  return DateTime(year, month, day);
}

/// `DateTime` → the `YYYY-MM-DD` calendar-date string the backend expects for
/// `occurredAt`. Deliberately not an instant (no `.toUtc()`) — a date picker
/// selection is a calendar day, and converting it to an instant can shift it
/// across the day boundary depending on the device's timezone.
String formatCalendarDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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
