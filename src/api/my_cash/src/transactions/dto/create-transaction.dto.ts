import { TransactionType } from '../transaction-type.enum';
import type {
  RecurrenceFrequency,
  RecurrenceUnit,
} from '../interfaces/transaction.interface';

export interface CreateTransactionDto {
  title: string;
  amount: number;
  type: TransactionType;
  category: string;
  occurredAt: string;
  notes?: string;
  source?: string;
  cardId?: string;
  /** null explicitly clears recurrence (used when editing a transaction to turn it off). */
  recurrenceFrequency?: RecurrenceFrequency | null;
  recurrenceInterval?: number | null;
  recurrenceUnit?: RecurrenceUnit | null;
  /** Total parcelas for an installment purchase; implies monthly recurrence. */
  installmentsTotal?: number;
  /** Reminder toggle: notify the user on this transaction's due date. */
  notifyOnDueDate?: boolean;
}