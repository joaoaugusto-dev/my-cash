import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
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

@Injectable()
export class TransactionsService {
  constructor(
    @Inject(TRANSACTIONS_REPOSITORY)
    private readonly transactionsRepository: TransactionsRepository,
  ) {}

  async findAll(
    authContext: RepositoryAuthContext,
    userId: string,
    type?: TransactionType,
    month?: string,
  ): Promise<Transaction[]> {
    return this.transactionsRepository.findAll(authContext, userId, {
      type,
      month,
    });
  }

  async getSummary(
    authContext: RepositoryAuthContext,
    userId: string,
    month?: string,
  ): Promise<TransactionSummary> {
    const scopedTransactions = await this.findAll(
      authContext,
      userId,
      undefined,
      month,
    );

    const income = scopedTransactions
      .filter((transaction) => transaction.type === TransactionType.INCOME)
      .reduce((total, transaction) => total + transaction.amount, 0);

    const expense = scopedTransactions
      .filter((transaction) => transaction.type === TransactionType.EXPENSE)
      .reduce((total, transaction) => total + transaction.amount, 0);

    return {
      month: month ?? this.currentMonth(),
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
    return this.transactionsRepository.findOne(authContext, userId, id);
  }

  async create(
    authContext: RepositoryAuthContext,
    userId: string,
    dto: CreateTransactionDto,
  ): Promise<Transaction> {
    this.assertValidPayload(dto);

    const now = new Date().toISOString();
    const transaction: Transaction = {
      id: randomUUID(),
      userId,
      title: dto.title.trim(),
      amount: this.normalizeAmount(dto.amount),
      type: dto.type,
      category: dto.category.trim(),
      occurredAt: this.normalizeDate(dto.occurredAt),
      notes: this.normalizeOptionalString(dto.notes),
      source: this.normalizeOptionalString(dto.source),
      createdAt: now,
      updatedAt: now,
    };

    return this.transactionsRepository.create(authContext, transaction);
  }

  async update(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
    dto: UpdateTransactionDto,
  ): Promise<Transaction> {
    const transaction = await this.findOne(authContext, userId, id);
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

    nextTransaction.updatedAt = new Date().toISOString();

    return this.transactionsRepository.update(authContext, nextTransaction);
  }

  async remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void> {
    await this.transactionsRepository.remove(authContext, userId, id);
  }

  private assertValidPayload(dto: CreateTransactionDto): void {
    this.normalizeRequiredString(dto.title, 'title');
    this.normalizeRequiredString(dto.category, 'category');
    this.assertType(dto.type);
    this.normalizeAmount(dto.amount);
    this.normalizeDate(dto.occurredAt);
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
