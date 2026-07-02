import { NotFoundException } from '@nestjs/common';
import { createClient } from '@supabase/supabase-js';
import { Card } from './interfaces/card.interface';
import {
  type CardsRepository,
  type RepositoryAuthContext,
} from './cards.repository';

interface CardRow {
  id: string;
  user_id: string;
  name: string;
  brand: string;
  last_digits: string;
  limit_amount: number;
  closing_day: number;
  due_day: number;
  created_at: string;
  updated_at: string;
}

export class SupabaseCardsRepository implements CardsRepository {
  constructor(
    private readonly supabaseUrl: string,
    private readonly supabaseAnonKey: string,
  ) {}

  async findAll(
    authContext: RepositoryAuthContext,
    userId: string,
  ): Promise<Card[]> {
    const { data, error } = await this.client(authContext)
      .from('cards')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    return (data ?? []).map((row) => this.fromRow(row as CardRow));
  }

  async findOne(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Card> {
    const { data, error } = await this.client(authContext)
      .from('cards')
      .select('*')
      .eq('user_id', userId)
      .eq('id', id)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Card ${id} not found`);
    }

    return this.fromRow(data as CardRow);
  }

  async create(authContext: RepositoryAuthContext, card: Card): Promise<Card> {
    const { data, error } = await this.client(authContext)
      .from('cards')
      .insert(this.toRow(card))
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    return this.fromRow(data as CardRow);
  }

  async update(authContext: RepositoryAuthContext, card: Card): Promise<Card> {
    const { data, error } = await this.client(authContext)
      .from('cards')
      .update(this.toRow(card))
      .eq('user_id', card.userId)
      .eq('id', card.id)
      .select('*')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Card ${card.id} not found`);
    }

    return this.fromRow(data as CardRow);
  }

  async remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void> {
    const { data, error } = await this.client(authContext)
      .from('cards')
      .delete()
      .eq('user_id', userId)
      .eq('id', id)
      .select('id')
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!data) {
      throw new NotFoundException(`Card ${id} not found`);
    }
  }

  private client(authContext: RepositoryAuthContext) {
    return createClient(this.supabaseUrl, this.supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${authContext.accessToken}`,
        },
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  private toRow(card: Card) {
    return {
      id: card.id,
      user_id: card.userId,
      name: card.name,
      brand: card.brand,
      last_digits: card.lastDigits,
      limit_amount: card.limitAmount,
      closing_day: card.closingDay,
      due_day: card.dueDay,
      created_at: card.createdAt,
      updated_at: card.updatedAt,
    };
  }

  private fromRow(row: CardRow): Card {
    return {
      id: row.id,
      userId: row.user_id,
      name: row.name,
      brand: row.brand,
      lastDigits: row.last_digits,
      limitAmount: row.limit_amount,
      closingDay: row.closing_day,
      dueDay: row.due_day,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
