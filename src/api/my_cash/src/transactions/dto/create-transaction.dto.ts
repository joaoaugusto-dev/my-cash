import { TransactionType } from '../transaction-type.enum';

export interface CreateTransactionDto {
  title: string;
  amount: number;
  type: TransactionType;
  category: string;
  occurredAt: string;
  notes?: string;
  source?: string;
  cardId?: string;
}