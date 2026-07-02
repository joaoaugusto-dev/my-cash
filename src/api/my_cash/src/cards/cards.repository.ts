import { Card } from './interfaces/card.interface';

export interface RepositoryAuthContext {
  accessToken: string;
}

export interface CardsRepository {
  findAll(authContext: RepositoryAuthContext, userId: string): Promise<Card[]>;
  findOne(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Card>;
  create(authContext: RepositoryAuthContext, card: Card): Promise<Card>;
  update(authContext: RepositoryAuthContext, card: Card): Promise<Card>;
  remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void>;
}

export const CARDS_REPOSITORY = 'CARDS_REPOSITORY';
