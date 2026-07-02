import { NotFoundException } from '@nestjs/common';
import { Card } from './interfaces/card.interface';
import {
  type CardsRepository,
  type RepositoryAuthContext,
} from './cards.repository';

export class InMemoryCardsRepository implements CardsRepository {
  private readonly cardsByUserId = new Map<string, Card[]>();

  async findAll(
    _authContext: RepositoryAuthContext,
    userId: string,
  ): Promise<Card[]> {
    return this.cardsByUserId.get(userId) ?? [];
  }

  async findOne(
    _authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Card> {
    const card = (this.cardsByUserId.get(userId) ?? []).find(
      (item) => item.id === id,
    );

    if (!card) {
      throw new NotFoundException(`Card ${id} not found`);
    }

    return card;
  }

  async create(_authContext: RepositoryAuthContext, card: Card): Promise<Card> {
    const cards = this.cardsByUserId.get(card.userId) ?? [];
    this.cardsByUserId.set(card.userId, [card, ...cards]);

    return card;
  }

  async update(_authContext: RepositoryAuthContext, card: Card): Promise<Card> {
    const cards = this.cardsByUserId.get(card.userId) ?? [];
    const index = cards.findIndex((item) => item.id === card.id);

    if (index === -1) {
      throw new NotFoundException(`Card ${card.id} not found`);
    }

    cards[index] = card;
    this.cardsByUserId.set(card.userId, [...cards]);

    return card;
  }

  async remove(
    _authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void> {
    const cards = this.cardsByUserId.get(userId) ?? [];
    const nextCards = cards.filter((card) => card.id !== id);

    if (nextCards.length === cards.length) {
      throw new NotFoundException(`Card ${id} not found`);
    }

    this.cardsByUserId.set(userId, nextCards);
  }
}
