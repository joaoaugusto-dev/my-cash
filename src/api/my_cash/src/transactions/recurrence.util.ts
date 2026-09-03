import { Transaction } from './interfaces/transaction.interface';

const OCCURRENCE_ID_SEPARATOR = '::';

export interface PeriodWindow {
  start: Date;
  end: Date;
}

export function buildOccurrenceId(anchorId: string, occurredAt: string): string {
  return `${anchorId}${OCCURRENCE_ID_SEPARATOR}${occurredAt}`;
}

/** Splits a transaction id into its anchor id and (if virtual) occurrence date. */
export function parseOccurrenceId(id: string): {
  anchorId: string;
  occurrenceDate?: string;
} {
  const separatorIndex = id.indexOf(OCCURRENCE_ID_SEPARATOR);
  if (separatorIndex === -1) {
    return { anchorId: id };
  }

  return {
    anchorId: id.slice(0, separatorIndex),
    occurrenceDate: id.slice(separatorIndex + OCCURRENCE_ID_SEPARATOR.length),
  };
}

export function resolvePeriodWindow(month?: string, year?: string): PeriodWindow {
  if (year) {
    const start = new Date(`${year}-01-01T00:00:00.000Z`);
    const end = new Date(start);
    end.setUTCFullYear(end.getUTCFullYear() + 1);
    return { start, end };
  }

  const resolvedMonth = month ?? new Date().toISOString().slice(0, 7);
  const start = new Date(`${resolvedMonth}-01T00:00:00.000Z`);
  const end = new Date(start);
  end.setUTCMonth(end.getUTCMonth() + 1);
  return { start, end };
}

/** Adds months, clamping the day so it never overflows into a later month (e.g. Jan 31 + 1 -> Feb 28, not Mar 3). */
export function addMonths(date: Date, months: number): Date {
  const next = new Date(date);
  const day = next.getUTCDate();
  next.setUTCDate(1);
  next.setUTCMonth(next.getUTCMonth() + months);
  const daysInTarget = new Date(
    Date.UTC(next.getUTCFullYear(), next.getUTCMonth() + 1, 0),
  ).getUTCDate();
  next.setUTCDate(Math.min(day, daysInTarget));
  return next;
}

/**
 * Splits `total` into `count` cents-rounded installments that sum back to the
 * original total exactly — the rounding remainder lands on the last one.
 * Mirrors the frontend's splitIntoInstallments so both sides agree.
 */
export function splitAmountEvenly(total: number, count: number): number[] {
  if (count <= 1) return [total];

  const perInstallment = roundToCents(total / count);
  const last = roundToCents(total - perInstallment * (count - 1));
  return [...Array(count - 1).fill(perInstallment), last];
}

function roundToCents(value: number): number {
  return Math.round(value * 100) / 100;
}

function addStep(date: Date, anchor: Transaction): Date {
  const next = new Date(date);
  const interval = anchor.recurrenceInterval ?? 1;

  switch (anchor.recurrenceFrequency) {
    case 'weekly':
      next.setUTCDate(next.getUTCDate() + 7 * interval);
      break;
    case 'yearly':
      next.setUTCFullYear(next.getUTCFullYear() + interval);
      break;
    case 'custom':
      if (anchor.recurrenceUnit === 'years') {
        next.setUTCFullYear(next.getUTCFullYear() + interval);
      } else if (anchor.recurrenceUnit === 'days') {
        next.setUTCDate(next.getUTCDate() + interval);
      } else {
        return addMonths(next, interval);
      }
      break;
    case 'monthly':
    default:
      return addMonths(next, interval);
  }

  return next;
}

/**
 * Expands a recurring anchor transaction into every occurrence landing inside
 * [window.start, window.end) — like a calendar app expanding a recurring
 * event. The anchor row itself is never returned, only its virtual
 * occurrences (ids of the form `${anchorId}::${occurrenceIso}`).
 *
 * ponytail: bounded by a 5000-step guard so a malformed recurrence (e.g.
 * interval 0) can't loop forever; real recurrences never get near that.
 */
export function expandRecurrence(
  anchor: Transaction,
  window: PeriodWindow,
): Transaction[] {
  if (!anchor.recurrenceFrequency) {
    return [];
  }

  const until = anchor.recurrenceUntil
    ? new Date(anchor.recurrenceUntil)
    : null;
  const exceptions = new Set(anchor.recurrenceExceptions ?? []);
  // Installments are just a bounded monthly recurrence where each occurrence
  // gets its own slice of the total amount and a "(i/n)" title suffix.
  const installmentAmounts = anchor.installmentsTotal
    ? splitAmountEvenly(anchor.amount, anchor.installmentsTotal)
    : null;

  let occurrence = new Date(anchor.occurredAt);
  const occurrences: Transaction[] = [];
  let index = 0;
  let guard = 0;

  while (occurrence < window.start) {
    if (until && occurrence >= until) return occurrences;
    occurrence = addStep(occurrence, anchor);
    index += 1;
    if (++guard > 5000) return occurrences;
  }

  while (occurrence < window.end) {
    if (until && occurrence >= until) break;
    if (installmentAmounts && index >= installmentAmounts.length) break;

    const occurredAt = occurrence.toISOString();
    if (!exceptions.has(occurredAt.slice(0, 10))) {
      occurrences.push({
        ...anchor,
        id: buildOccurrenceId(anchor.id, occurredAt),
        occurredAt,
        seriesId: anchor.id,
        amount: installmentAmounts ? installmentAmounts[index] : anchor.amount,
        title: installmentAmounts
          ? `${anchor.title} (${index + 1}/${anchor.installmentsTotal})`
          : anchor.title,
      });
    }

    occurrence = addStep(occurrence, anchor);
    index += 1;
    if (++guard > 5000) break;
  }

  return occurrences;
}

/**
 * Whether a recurring anchor still generates at least one occurrence, ever.
 * Only meaningful for bounded series (recurrenceUntil set, e.g. after a
 * "delete this month forward" or an installment's inherent end) — an
 * open-ended series always has more, since exceptions are a finite list and
 * can never cover an infinite future.
 */
export function hasRemainingOccurrences(anchor: Transaction): boolean {
  if (!anchor.recurrenceUntil) {
    return true;
  }

  const start = new Date(anchor.occurredAt);
  const until = new Date(anchor.recurrenceUntil);
  if (until <= start) {
    return false;
  }

  return expandRecurrence(anchor, { start, end: until }).length > 0;
}
