import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionType } from './transaction-type.enum';
import { Transaction } from './interfaces/transaction.interface';

export interface TransactionFilters {
  type?: TransactionType;
  month?: string;
}

export interface RepositoryAuthContext {
  accessToken: string;
}

export interface TransactionsRepository {
  findAll(
    authContext: RepositoryAuthContext,
    userId: string,
    filters?: TransactionFilters,
  ): Promise<Transaction[]>;
  findOne(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Transaction>;
  create(
    authContext: RepositoryAuthContext,
    transaction: Transaction,
  ): Promise<Transaction>;
  update(
    authContext: RepositoryAuthContext,
    transaction: Transaction,
  ): Promise<Transaction>;
  remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void>;
}

export const TRANSACTIONS_REPOSITORY = 'TRANSACTIONS_REPOSITORY';

export interface TransactionsServiceInput {
  userId: string;
  dto: CreateTransactionDto;
}

export interface TransactionsUpdateInput {
  userId: string;
  id: string;
  dto: UpdateTransactionDto;
}
