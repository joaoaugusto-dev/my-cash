import { NotFoundException } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { Transaction } from './interfaces/transaction.interface';
import { TransactionFilters, TransactionsRepository } from './transactions.repository';

interface TransactionRow {
  id: string;
  user_id: string;
  title: string;
  amount: number;
  type: string;
  category: string;
  occurred_at: string;
  notes: string | null;
  source: string | null;
  created_at: string;
  updated_at: string;
}

export class SupabaseTransactionsRepository implements TransactionsRepository {
  constructor(private readonly supabase: SupabaseClient) {}

  async findAll(userId: string, filters?: TransactionFilters): Promise<Transaction[]> {
    let query = this.supabase
      .from('transactions')
      .select('*')
      .eq('user_id', userId)
      .order('occurred_at', { ascending: false });

    if (filters?.type) {
      query = query.eq('type', filters.type);
    }

    if (filters?.month) {
      const { startDate, endDate } = this.getMonthWindow(filters.month);
      query = query.gte('occurred_at', startDate).lt('occurred_at', endDate);
    }

    const { data, error } = await query;
    if (error) {
      throw error;
    }

    return (data ?? []).map((row) => this.fromRow(row as TransactionRow));
  }

  async findOne(userId: string, id: string): Promise<Transaction> {
    const { data, error } = await this.supabase
      .from('transactions')
      .select('*')
      .eq('user_id', userId)
      .eq('id', id)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Transaction ${id} not found`);
    }

    return this.fromRow(data as TransactionRow);
  }

  async create(transaction: Transaction): Promise<Transaction> {
    const { data, error } = await this.supabase
      .from('transactions')
      .insert(this.toRow(transaction))
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    return this.fromRow(data as TransactionRow);
  }

  async update(transaction: Transaction): Promise<Transaction> {
    const { data, error } = await this.supabase
      .from('transactions')
      .update(this.toRow(transaction))
      .eq('user_id', transaction.userId)
      .eq('id', transaction.id)
      .select('*')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Transaction ${transaction.id} not found`);
    }

    return this.fromRow(data as TransactionRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('transactions')
      .delete()
      .eq('user_id', userId)
      .eq('id', id)
      .select('id')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Transaction ${id} not found`);
    }
  }

  private toRow(transaction: Transaction) {
    return {
      id: transaction.id,
      user_id: transaction.userId,
      title: transaction.title,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      occurred_at: transaction.occurredAt,
      notes: transaction.notes ?? null,
      source: transaction.source ?? null,
      created_at: transaction.createdAt,
      updated_at: transaction.updatedAt,
    };
  }

  private fromRow(row: TransactionRow): Transaction {
    return {
      id: row.id,
      userId: row.user_id,
      title: row.title,
      amount: row.amount,
      type: row.type as Transaction['type'],
      category: row.category,
      occurredAt: row.occurred_at,
      notes: row.notes ?? undefined,
      source: row.source ?? undefined,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private getMonthWindow(month: string): { startDate: string; endDate: string } {
    const startDate = `${month}-01T00:00:00.000Z`;
    const endDate = new Date(startDate);
    endDate.setUTCMonth(endDate.getUTCMonth() + 1);

    return {
      startDate,
      endDate: endDate.toISOString(),
    };
  }
}