import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { CardsService } from '../cards/cards.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionType } from './transaction-type.enum';
import {
  Transaction,
  TransactionSummary,
} from './interfaces/transaction.interface';
import {
  TRANSACTIONS_REPOSITORY,
  type RepositoryAuthContext,
  type TransactionsRepository,
} from './transactions.repository';
import {
  addMonths,
  expandRecurrence,
  hasRemainingOccurrences,
  parseOccurrenceId,
  resolvePeriodWindow,
} from './recurrence.util';

const RECURRENCE_FREQUENCIES = ['weekly', 'monthly', 'yearly', 'custom'];
const RECURRENCE_UNITS = ['days', 'months', 'years'];

@Injectable()
export class TransactionsService {
  constructor(
    @Inject(TRANSACTIONS_REPOSITORY)
    private readonly transactionsRepository: TransactionsRepository,
    private readonly cardsService: CardsService,
  ) {}

  /** Throws NotFoundException if cardId is set but doesn't belong to userId. */
  private async assertCardOwnership(
    authContext: RepositoryAuthContext,
    userId: string,
    cardId: string | undefined,
  ): Promise<void> {
    if (!cardId) return;
    await this.cardsService.findOne(authContext, userId, cardId);
  }

  async findAll(
    authContext: RepositoryAuthContext,
    userId: string,
    type?: TransactionType,
    month?: string,
    year?: string,
  ): Promise<Transaction[]> {
    const window = resolvePeriodWindow(month, year);

    const [transactions, anchors] = await Promise.all([
      this.transactionsRepository.findAll(authContext, userId, {
        type,
        month,
        year,
      }),
      this.transactionsRepository.findRecurringAnchors(
        authContext,
        userId,
        window.end.toISOString(),
      ),
    ]);

    // Anchors never render as-is — only their expanded occurrences do —
    // so drop them here to avoid double-counting the anchor's own start date.
    const nonRecurring = transactions.filter((t) => !t.recurrenceFrequency);
    const occurrences = anchors
      .filter((anchor) => (type ? anchor.type === type : true))
      .flatMap((anchor) => expandRecurrence(anchor, window));

    return [...nonRecurring, ...occurrences].sort((a, b) =>
      b.occurredAt.localeCompare(a.occurredAt),
    );
  }

  async getSummary(
    authContext: RepositoryAuthContext,
    userId: string,
    month?: string,
    year?: string,
  ): Promise<TransactionSummary> {
    const scopedTransactions = await this.findAll(
      authContext,
      userId,
      undefined,
      month,
      year,
    );

    const income = scopedTransactions
      .filter((transaction) => transaction.type === TransactionType.INCOME)
      .reduce((total, transaction) => total + transaction.amount, 0);

    const expense = scopedTransactions
      .filter((transaction) => transaction.type === TransactionType.EXPENSE)
      .reduce((total, transaction) => total + transaction.amount, 0);

    const period = year ?? month ?? this.currentMonth();

    return {
      month: period,
      income,
      expense,
      balance: income - expense,
      entriesCount: scopedTransactions.filter(
        (transaction) => transaction.type === TransactionType.INCOME,
      ).length,
      exitsCount: scopedTransactions.filter(
        (transaction) => transaction.type === TransactionType.EXPENSE,
      ).length,
    };
  }

  async findOne(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Transaction> {
    const { anchorId, occurrenceDate } = parseOccurrenceId(id);
    const anchor = await this.transactionsRepository.findOne(
      authContext,
      userId,
      anchorId,
    );

    if (!occurrenceDate) {
      return anchor;
    }

    return { ...anchor, id, occurredAt: occurrenceDate, seriesId: anchor.id };
  }

  async create(
    authContext: RepositoryAuthContext,
    userId: string,
    dto: CreateTransactionDto,
  ): Promise<Transaction> {
    this.assertValidPayload(dto);
    await this.assertCardOwnership(authContext, userId, dto.cardId);

    const now = new Date().toISOString();
    const occurredAt = this.normalizeDate(dto.occurredAt);
    const transaction: Transaction = {
      id: randomUUID(),
      userId,
      title: dto.title.trim(),
      amount: this.normalizeAmount(dto.amount),
      type: dto.type,
      category: dto.category.trim(),
      occurredAt,
      notes: this.normalizeOptionalString(dto.notes),
      source: this.normalizeOptionalString(dto.source),
      cardId: dto.cardId,
      createdAt: now,
      updatedAt: now,
    };

    if (dto.installmentsTotal) {
      // Installments never materialize N rows — one anchor row recurs
      // monthly, bounded by count, same mechanism as a recurring transaction.
      this.assertInstallments(dto.installmentsTotal);
      transaction.installmentsTotal = dto.installmentsTotal;
      transaction.recurrenceFrequency = 'monthly';
      transaction.recurrenceInterval = 1;
      transaction.recurrenceUntil = addMonths(
        new Date(occurredAt),
        dto.installmentsTotal,
      ).toISOString();
      transaction.recurrenceExceptions = [];
    } else {
      this.assertRecurrence(dto.recurrenceFrequency, dto.recurrenceUnit);
      transaction.recurrenceFrequency = dto.recurrenceFrequency ?? undefined;
      transaction.recurrenceInterval = dto.recurrenceFrequency
        ? (dto.recurrenceInterval ?? 1)
        : undefined;
      transaction.recurrenceUnit =
        dto.recurrenceFrequency === 'custom'
          ? (dto.recurrenceUnit ?? undefined)
          : undefined;
      transaction.recurrenceExceptions = dto.recurrenceFrequency
        ? []
        : undefined;
    }

    return this.transactionsRepository.create(authContext, transaction);
  }

  async update(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
    dto: UpdateTransactionDto,
    scope?: 'this' | 'forward',
  ): Promise<Transaction> {
    const { anchorId, occurrenceDate } = parseOccurrenceId(id);
    const anchor = await this.transactionsRepository.findOne(
      authContext,
      userId,
      anchorId,
    );

    // A plain transaction, a bare-anchor edit, or an installment (which,
    // like a refund, is edited/deleted as one whole purchase — see remove())
    // just gets its fields patched directly, same as before.
    if (!occurrenceDate || anchor.installmentsTotal) {
      const patch =
        occurrenceDate && anchor.installmentsTotal
          ? this.dropUnchangedDisplayFields(anchor, occurrenceDate, dto)
          : dto;
      return this.updateFields(authContext, userId, anchor, patch);
    }

    // Editing one occurrence of an open-ended recurring series: split it so
    // past occurrences keep their original values, the same trick a
    // calendar app uses for "this event" vs "this and following events".
    const editScope = scope ?? 'this';
    const nextAnchor = { ...anchor };

    if (editScope === 'forward') {
      nextAnchor.recurrenceUntil = occurrenceDate;
    } else {
      const exceptions = new Set(anchor.recurrenceExceptions ?? []);
      exceptions.add(occurrenceDate.slice(0, 10));
      nextAnchor.recurrenceExceptions = [...exceptions];
    }

    if (!hasRemainingOccurrences(nextAnchor)) {
      await this.transactionsRepository.remove(authContext, userId, anchor.id);
    } else {
      nextAnchor.updatedAt = new Date().toISOString();
      await this.transactionsRepository.update(authContext, nextAnchor);
    }

    const splitDto: CreateTransactionDto = {
      title: dto.title ?? anchor.title,
      amount: dto.amount ?? anchor.amount,
      type: dto.type ?? anchor.type,
      category: dto.category ?? anchor.category,
      occurredAt: occurrenceDate,
      notes: dto.notes ?? anchor.notes,
      source: dto.source ?? anchor.source,
      cardId: dto.cardId ?? anchor.cardId,
      ...(editScope === 'forward'
        ? {
            recurrenceFrequency: anchor.recurrenceFrequency,
            recurrenceInterval: anchor.recurrenceInterval,
            recurrenceUnit: anchor.recurrenceUnit,
          }
        : {}),
    };

    return this.create(authContext, userId, splitDto);
  }

  /**
   * The client only ever sees an installment occurrence's *expanded* title
   * ("Compra (2/9)") and split amount (total/9), never the anchor's raw
   * total — so a save that doesn't touch those fields round-trips the
   * display values back as if they were edits, corrupting the anchor
   * (double-suffixed title, re-split amount) on every subsequent read. Drop
   * any field that matches what was actually displayed for this occurrence.
   */
  private dropUnchangedDisplayFields(
    anchor: Transaction,
    occurrenceDate: string,
    dto: UpdateTransactionDto,
  ): UpdateTransactionDto {
    const at = new Date(occurrenceDate);
    const [occurrence] = expandRecurrence(anchor, {
      start: at,
      end: new Date(at.getTime() + 1),
    });
    if (!occurrence) return dto;

    const patch = { ...dto };
    if (patch.title === occurrence.title) delete patch.title;
    if (patch.amount === occurrence.amount) delete patch.amount;
    return patch;
  }

  private async updateFields(
    authContext: RepositoryAuthContext,
    userId: string,
    transaction: Transaction,
    dto: UpdateTransactionDto,
  ): Promise<Transaction> {
    const nextTransaction = { ...transaction };

    if (dto.title !== undefined) {
      nextTransaction.title = this.normalizeRequiredString(dto.title, 'title');
    }

    if (dto.amount !== undefined) {
      nextTransaction.amount = this.normalizeAmount(dto.amount);
    }

    if (dto.type !== undefined) {
      this.assertType(dto.type);
      nextTransaction.type = dto.type;
    }

    if (dto.category !== undefined) {
      nextTransaction.category = this.normalizeRequiredString(
        dto.category,
        'category',
      );
    }

    if (dto.occurredAt !== undefined) {
      nextTransaction.occurredAt = this.normalizeDate(dto.occurredAt);
    }

    if (dto.notes !== undefined) {
      nextTransaction.notes = this.normalizeOptionalString(dto.notes);
    }

    if (dto.source !== undefined) {
      nextTransaction.source = this.normalizeOptionalString(dto.source);
    }

    if (dto.cardId !== undefined) {
      await this.assertCardOwnership(authContext, userId, dto.cardId);
      nextTransaction.cardId = dto.cardId;
    }

    if (dto.recurrenceFrequency !== undefined) {
      if (!dto.recurrenceFrequency) {
        // Explicit null: the edit form turned recurrence off for this series.
        nextTransaction.recurrenceFrequency = undefined;
        nextTransaction.recurrenceInterval = undefined;
        nextTransaction.recurrenceUnit = undefined;
        nextTransaction.recurrenceUntil = undefined;
        nextTransaction.recurrenceExceptions = undefined;
      } else {
        this.assertRecurrence(dto.recurrenceFrequency, dto.recurrenceUnit);
        nextTransaction.recurrenceFrequency = dto.recurrenceFrequency;
        nextTransaction.recurrenceInterval = dto.recurrenceInterval ?? 1;
        nextTransaction.recurrenceUnit =
          dto.recurrenceFrequency === 'custom'
            ? (dto.recurrenceUnit ?? undefined)
            : undefined;
      }
    }

    nextTransaction.updatedAt = new Date().toISOString();

    return this.transactionsRepository.update(authContext, nextTransaction);
  }

  async remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
    scope?: 'this' | 'forward',
  ): Promise<void> {
    const { anchorId, occurrenceDate } = parseOccurrenceId(id);

    if (!occurrenceDate) {
      await this.transactionsRepository.remove(authContext, userId, anchorId);
      return;
    }

    const anchor = await this.transactionsRepository.findOne(
      authContext,
      userId,
      anchorId,
    );

    if (anchor.installmentsTotal) {
      // Installments are one purchase, not independent events — removing
      // any parcela reverses the whole thing, past parcelas included.
      await this.transactionsRepository.remove(authContext, userId, anchor.id);
      return;
    }

    if (scope === 'forward') {
      anchor.recurrenceUntil = occurrenceDate;
    } else {
      const exceptions = new Set(anchor.recurrenceExceptions ?? []);
      exceptions.add(occurrenceDate.slice(0, 10));
      anchor.recurrenceExceptions = [...exceptions];
    }

    if (!hasRemainingOccurrences(anchor)) {
      // No occurrence left anywhere, past or future — the anchor has no
      // purpose anymore.
      await this.transactionsRepository.remove(authContext, userId, anchor.id);
      return;
    }

    anchor.updatedAt = new Date().toISOString();
    await this.transactionsRepository.update(authContext, anchor);
  }

  private assertValidPayload(dto: CreateTransactionDto): void {
    this.normalizeRequiredString(dto.title, 'title');
    this.normalizeRequiredString(dto.category, 'category');
    this.assertType(dto.type);
    this.normalizeAmount(dto.amount);
    this.normalizeDate(dto.occurredAt);
  }

  private assertRecurrence(
    frequency: string | null | undefined,
    unit: string | null | undefined,
  ): void {
    if (!frequency) return;

    if (!RECURRENCE_FREQUENCIES.includes(frequency)) {
      throw new BadRequestException(
        'recurrenceFrequency must be weekly, monthly, yearly or custom',
      );
    }

    if (frequency === 'custom' && !RECURRENCE_UNITS.includes(unit ?? '')) {
      throw new BadRequestException(
        'recurrenceUnit must be days, months or years for custom recurrence',
      );
    }
  }

  private assertInstallments(count: number): void {
    if (!Number.isInteger(count) || count < 2 || count > 36) {
      throw new BadRequestException(
        'installmentsTotal must be an integer between 2 and 36',
      );
    }
  }

  private assertType(type: TransactionType): void {
    if (!Object.values(TransactionType).includes(type)) {
      throw new BadRequestException('type must be income or expense');
    }
  }

  private normalizeRequiredString(value: string, fieldName: string): string {
    if (typeof value !== 'string') {
      throw new BadRequestException(`${fieldName} must be a string`);
    }

    const normalized = value.trim();
    if (!normalized) {
      throw new BadRequestException(`${fieldName} cannot be empty`);
    }

    return normalized;
  }

  private normalizeOptionalString(value?: string): string | undefined {
    if (value === undefined) {
      return undefined;
    }

    return value.trim() || undefined;
  }

  private normalizeAmount(amount: number): number {
    if (typeof amount !== 'number' || Number.isNaN(amount) || amount <= 0) {
      throw new BadRequestException('amount must be a positive number');
    }

    return Number(amount.toFixed(2));
  }

  private normalizeDate(date: string): string {
    const parsedDate = new Date(date);
    if (Number.isNaN(parsedDate.getTime())) {
      throw new BadRequestException('occurredAt must be a valid ISO date');
    }

    return parsedDate.toISOString();
  }

  private currentMonth(): string {
    return new Date().toISOString().slice(0, 7);
  }
}
