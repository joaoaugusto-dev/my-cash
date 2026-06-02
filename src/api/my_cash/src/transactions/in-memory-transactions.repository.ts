import { NotFoundException } from '@nestjs/common';
import { Transaction } from './interfaces/transaction.interface';
import {
  type RepositoryAuthContext,
  type TransactionFilters,
  type TransactionsRepository,
} from './transactions.repository';

export class InMemoryTransactionsRepository implements TransactionsRepository {
  private readonly transactionsByUserId = new Map<string, Transaction[]>();

  async findAll(
    _authContext: RepositoryAuthContext,
    userId: string,
    filters?: TransactionFilters,
  ): Promise<Transaction[]> {
    const transactions = this.transactionsByUserId.get(userId) ?? [];

    return transactions.filter((transaction) => {
      const matchesType = filters?.type
        ? transaction.type === filters.type
        : true;
      const matchesMonth = filters?.month
        ? transaction.occurredAt.startsWith(filters.month)
        : true;

      return matchesType && matchesMonth;
    });
  }

  async findOne(
    _authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Transaction> {
    const transaction = (this.transactionsByUserId.get(userId) ?? []).find(
      (item) => item.id === id,
    );

    if (!transaction) {
      throw new NotFoundException(`Transaction ${id} not found`);
    }

    return transaction;
  }

  async create(
    _authContext: RepositoryAuthContext,
    transaction: Transaction,
  ): Promise<Transaction> {
    const transactions =
      this.transactionsByUserId.get(transaction.userId) ?? [];
    this.transactionsByUserId.set(transaction.userId, [
      transaction,
      ...transactions,
    ]);

    return transaction;
  }

  async update(
    _authContext: RepositoryAuthContext,
    transaction: Transaction,
  ): Promise<Transaction> {
    const transactions =
      this.transactionsByUserId.get(transaction.userId) ?? [];
    const index = transactions.findIndex((item) => item.id === transaction.id);

    if (index === -1) {
      throw new NotFoundException(`Transaction ${transaction.id} not found`);
    }

    transactions[index] = transaction;
    this.transactionsByUserId.set(transaction.userId, [...transactions]);

    return transaction;
  }

  async remove(
    _authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void> {
    const transactions = this.transactionsByUserId.get(userId) ?? [];
    const nextTransactions = transactions.filter(
      (transaction) => transaction.id !== id,
    );

    if (nextTransactions.length === transactions.length) {
      throw new NotFoundException(`Transaction ${id} not found`);
    }

    this.transactionsByUserId.set(userId, nextTransactions);
  }
}
