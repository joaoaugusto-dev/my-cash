import { ChatTools } from './chat.tools';
import type { CardsService } from '../cards/cards.service';
import type { TransactionsService } from '../transactions/transactions.service';

const ctx = {
  authContext: { accessToken: 'token' },
  userId: 'user-1',
};

function makeTools(transactions: Partial<TransactionsService> = {}) {
  return new ChatTools(
    { create: jest.fn(), update: jest.fn(), ...transactions } as unknown as TransactionsService,
    {} as CardsService,
  );
}

describe('ChatTools', () => {
  it('rejects create_transaction with source "Crédito" and no cardId, without hitting the service', async () => {
    const create = jest.fn();
    const tools = makeTools({ create });

    const result = await tools.run(ctx, 'create_transaction', {
      title: 'Bolo',
      amount: 10,
      type: 'expense',
      category: 'Alimentação',
      occurredAt: '2026-09-02',
      source: 'Crédito',
    });

    expect(create).not.toHaveBeenCalled();
    expect(JSON.parse(result)).toEqual({
      error: expect.stringContaining('list_cards'),
    });
  });

  it('allows create_transaction with source "Crédito" once cardId is set', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'tx-1' });
    const tools = makeTools({ create });

    await tools.run(ctx, 'create_transaction', {
      title: 'Bolo',
      amount: 10,
      type: 'expense',
      category: 'Alimentação',
      occurredAt: '2026-09-02',
      source: 'Crédito',
      cardId: 'card-1',
    });

    expect(create).toHaveBeenCalled();
  });
});
