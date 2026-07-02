import { TransactionType } from '../transaction-type.enum';

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
}

export interface TransactionSummary {
  month: string;
  income: number;
  expense: number;
  balance: number;
  entriesCount: number;
  exitsCount: number;
}