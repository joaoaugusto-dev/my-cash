import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:my_cash/src/domain/models/financial_transaction.dart';
import 'package:my_cash/src/utils/formatters.dart';

/// The hour of day (local time) reminders fire at.
const int dueDateReminderHour = 9;

/// Stable notification id derived from a transaction id — recurring
/// occurrences already arrive as distinct transaction objects (one per date,
/// see recurrence.util.ts), so each gets its own id and its own reminder.
int notificationIdFor(String transactionId) =>
    transactionId.hashCode & 0x7fffffff;

/// The local date/time a due-date reminder should fire for [occurredAtIso],
/// or null if that date has already passed (nothing left to schedule).
DateTime? scheduledDateFor(String occurredAtIso, {DateTime? now}) {
  final dueDate = parseCalendarDate(occurredAtIso) ?? DateTime.parse(occurredAtIso);
  final scheduledAt = DateTime(
    dueDate.year,
    dueDate.month,
    dueDate.day,
    dueDateReminderHour,
  );
  if (scheduledAt.isBefore(now ?? DateTime.now())) {
    return null;
  }
  return scheduledAt;
}

/// Schedules a local reminder for expenses with `notifyOnDueDate` set. A
/// recurring series is already expanded by the backend into one transaction
/// per occurrence, so scheduling one reminder per loaded transaction
/// naturally covers "notify every recurrence" too — no separate recurring
/// notification logic needed.
///
/// ponytail: only reconciles whatever transaction list is currently loaded
/// (the visible month/year) — an occurrence far in the future isn't
/// scheduled until the user opens that period. Add a wider pre-scan if that
/// ever matters.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> syncWithTransactions(
    List<FinancialTransaction> transactions,
  ) async {
    if (!_initialized) return;

    for (final transaction in transactions) {
      final id = notificationIdFor(transaction.id);
      if (!transaction.notifyOnDueDate ||
          transaction.type != FinancialTransactionType.expense) {
        await _plugin.cancel(id: id);
        continue;
      }

      final scheduledAt = scheduledDateFor(transaction.occurredAt);
      if (scheduledAt == null) {
        await _plugin.cancel(id: id);
        continue;
      }

      await _plugin.zonedSchedule(
        id: id,
        title: 'Vencimento hoje',
        body: transaction.title,
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'due_date_reminders',
            'Lembretes de vencimento',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
