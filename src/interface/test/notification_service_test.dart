import 'package:flutter_test/flutter_test.dart';
import 'package:my_cash/src/data/services/notification_service.dart';

void main() {
  test('scheduledDateFor returns 9am local on the due date', () {
    final dueDate = DateTime(2026, 8, 10, dueDateReminderHour);
    final result = scheduledDateFor(
      dueDate.toUtc().toIso8601String(),
      now: DateTime(2026, 8, 1),
    );
    expect(result, DateTime(2026, 8, 10, dueDateReminderHour));
  });

  test('scheduledDateFor returns null once the due date has passed', () {
    final dueDate = DateTime(2026, 8, 10, dueDateReminderHour);
    final result = scheduledDateFor(
      dueDate.toUtc().toIso8601String(),
      now: DateTime(2026, 8, 11),
    );
    expect(result, isNull);
  });

  test('notificationIdFor is stable and non-negative', () {
    final id = notificationIdFor('same-transaction-id');
    expect(id, notificationIdFor('same-transaction-id'));
    expect(id, greaterThanOrEqualTo(0));
  });
}
