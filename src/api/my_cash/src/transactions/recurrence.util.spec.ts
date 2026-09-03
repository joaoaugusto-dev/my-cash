import { TransactionType } from './transaction-type.enum';
import { Transaction } from './interfaces/transaction.interface';
import {
  addMonths,
  buildOccurrenceId,
  expandRecurrence,
  parseOccurrenceId,
  resolvePeriodWindow,
} from './recurrence.util';

function anchor(overrides: Partial<Transaction> = {}): Transaction {
  return {
    id: 'anchor-1',
    userId: 'user-1',
    title: 'Aluguel',
    amount: 1500,
    type: TransactionType.EXPENSE,
    category: 'Moradia',
    occurredAt: '2026-01-05T00:00:00.000Z',
    createdAt: '2026-01-05T00:00:00.000Z',
    updatedAt: '2026-01-05T00:00:00.000Z',
    recurrenceFrequency: 'monthly',
    recurrenceInterval: 1,
    ...overrides,
  };
}

describe('recurrence.util', () => {
  it('expands a monthly recurrence into a later month', () => {
    const window = resolvePeriodWindow('2026-07');
    const occurrences = expandRecurrence(anchor(), window);

    expect(occurrences).toHaveLength(1);
    expect(occurrences[0].occurredAt).toBe('2026-07-05T00:00:00.000Z');
    expect(occurrences[0].seriesId).toBe('anchor-1');
    expect(occurrences[0].id).toBe(
      buildOccurrenceId('anchor-1', '2026-07-05T00:00:00.000Z'),
    );
  });

  it('skips a month listed in recurrenceExceptions', () => {
    const window = resolvePeriodWindow('2026-07');
    const occurrences = expandRecurrence(
      anchor({ recurrenceExceptions: ['2026-07-05'] }),
      window,
    );

    expect(occurrences).toHaveLength(0);
  });

  it('stops generating occurrences on/after recurrenceUntil', () => {
    const window = resolvePeriodWindow('2026-07');
    const occurrences = expandRecurrence(
      anchor({ recurrenceUntil: '2026-07-05T00:00:00.000Z' }),
      window,
    );

    expect(occurrences).toHaveLength(0);
  });

  it('produces nothing before the anchor start date', () => {
    const window = resolvePeriodWindow('2025-12');
    expect(expandRecurrence(anchor(), window)).toHaveLength(0);
  });

  it('clamps day-31 anchors instead of overflowing into the next month', () => {
    const window = resolvePeriodWindow('2026-02');
    const occurrences = expandRecurrence(
      anchor({ occurredAt: '2026-01-31T00:00:00.000Z' }),
      window,
    );

    expect(occurrences).toHaveLength(1);
    expect(occurrences[0].occurredAt).toBe('2026-02-28T00:00:00.000Z');
  });

  it('addMonths clamps to the last day of shorter target months', () => {
    expect(addMonths(new Date('2026-01-31T00:00:00.000Z'), 1).toISOString()).toBe(
      '2026-02-28T00:00:00.000Z',
    );
    expect(addMonths(new Date('2026-05-31T00:00:00.000Z'), 1).toISOString()).toBe(
      '2026-06-30T00:00:00.000Z',
    );
  });

  it('round-trips a virtual occurrence id', () => {
    const id = buildOccurrenceId('anchor-1', '2026-07-05T00:00:00.000Z');
    expect(parseOccurrenceId(id)).toEqual({
      anchorId: 'anchor-1',
      occurrenceDate: '2026-07-05T00:00:00.000Z',
    });
    expect(parseOccurrenceId('plain-id')).toEqual({ anchorId: 'plain-id' });
  });
});
