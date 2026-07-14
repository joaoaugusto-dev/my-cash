import { TransactionType } from '../transaction-type.enum';

export type RecurrenceFrequency = 'weekly' | 'monthly' | 'yearly' | 'custom';
export type RecurrenceUnit = 'days' | 'months' | 'years';

export interface Transaction {
  id: string;
  userId: string;
  title: string;
  amount: number;
  type: TransactionType;
  category: string;
  occurredAt: string;
  notes?: string;
  source?: string;
  cardId?: string;
  createdAt: string;
  updatedAt: string;
  /** Set on the anchor row of a recurring series (the transaction the user created). */
  recurrenceFrequency?: RecurrenceFrequency;
  recurrenceInterval?: number;
  recurrenceUnit?: RecurrenceUnit;
  /** Occurrences on/after this date are no longer generated. */
  recurrenceUntil?: string;
  /** Dates (YYYY-MM-DD) explicitly skipped via a "delete only this month". */
  recurrenceExceptions?: string[];
  /** Set only on virtual occurrences expanded from a recurring anchor; equals the anchor's real id. */
  seriesId?: string;
  /**
   * Set on an installment purchase's anchor row: total number of parcelas.
   * Implemented as a bounded monthly recurrence (see recurrence.util) so it
   * never materializes more than the one anchor row in the database —
   * `amount` on the anchor holds the full purchase total, split across
   * occurrences at read time.
   */
  installmentsTotal?: number;
}

export interface TransactionSummary {
  month: string;
  income: number;
  expense: number;
  balance: number;
  entriesCount: number;
  exitsCount: number;
}