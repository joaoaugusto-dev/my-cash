import { BadRequestException, NotFoundException } from '@nestjs/common';
import { InMemoryCardsRepository } from '../cards/in-memory-cards.repository';
import { CardsService } from '../cards/cards.service';
import { InMemoryTransactionsRepository } from './in-memory-transactions.repository';
import { TransactionType } from './transaction-type.enum';
import { TransactionsService } from './transactions.service';

describe('TransactionsService', () => {
  let service: TransactionsService;
  let cardsService: CardsService;
  const authContext = { accessToken: 'test-token' };

  beforeEach(() => {
    cardsService = new CardsService(new InMemoryCardsRepository());
    service = new TransactionsService(
      new InMemoryTransactionsRepository(),
      cardsService,
    );
  });

  it('should create and list transactions', async () => {
    const created = await service.create(authContext, 'user-1', {
      title: 'Salario',
      amount: 4500,
      type: TransactionType.INCOME,
      category: 'Trabalho',
      occurredAt: '2026-05-01T10:00:00.000Z',
      notes: 'Pagamento mensal',
      source: 'Empresa',
    });

    expect(created.id).toBeTruthy();
    expect(created.userId).toBe('user-1');
    expect(created.amount).toBe(4500);
    expect(created.type).toBe(TransactionType.INCOME);
    expect(created.category).toBe('Trabalho');
    await expect(service.findAll(authContext, 'user-1')).resolves.toHaveLength(
      1,
    );
    await expect(
      service.findAll(authContext, 'user-1', TransactionType.INCOME, '2026-05'),
    ).resolves.toHaveLength(1);
  });

  it('should summarize income and expense by month', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Salario',
      amount: 5000,
      type: TransactionType.INCOME,
      category: 'Trabalho',
      occurredAt: '2026-05-01T10:00:00.000Z',
    });

    await service.create(authContext, 'user-1', {
      title: 'Mercado',
      amount: 250.5,
      type: TransactionType.EXPENSE,
      category: 'Alimentacao',
      occurredAt: '2026-05-03T10:00:00.000Z',
    });

    await expect(
      service.getSummary(authContext, 'user-1', '2026-05'),
    ).resolves.toEqual({
      month: '2026-05',
      income: 5000,
      expense: 250.5,
      balance: 4749.5,
      entriesCount: 1,
      exitsCount: 1,
    });
  });

  it('should update and remove transactions', async () => {
    const created = await service.create(authContext, 'user-1', {
      title: 'Lanche',
      amount: 30,
      type: TransactionType.EXPENSE,
      category: 'Alimentacao',
      occurredAt: '2026-05-04T12:00:00.000Z',
    });

    const updated = await service.update(authContext, 'user-1', created.id, {
      amount: 35,
      notes: 'Incluiu bebida',
    });

    expect(updated.amount).toBe(35);
    expect(updated.notes).toBe('Incluiu bebida');

    await service.remove(authContext, 'user-1', created.id);
    await expect(service.findAll(authContext, 'user-1')).resolves.toHaveLength(
      0,
    );
  });

  it('should reject invalid transactions', async () => {
    await expect(
      service.create(authContext, 'user-1', {
        title: '',
        amount: 10,
        type: TransactionType.INCOME,
        category: 'Teste',
        occurredAt: '2026-05-01T00:00:00.000Z',
      }),
    ).rejects.toThrow(BadRequestException);

    await expect(
      service.findOne(authContext, 'user-1', 'missing'),
    ).rejects.toThrow(NotFoundException);
  });

  it('links a transaction to a card owned by the same user', async () => {
    const card = await cardsService.create(authContext, 'user-1', {
      name: 'Nubank',
      brand: 'Mastercard',
      lastDigits: '1234',
      limitAmount: 5000,
      closingDay: 10,
      dueDay: 17,
    });

    const created = await service.create(authContext, 'user-1', {
      title: 'Compra',
      amount: 100,
      type: TransactionType.EXPENSE,
      category: 'Compras',
      occurredAt: '2026-05-05T10:00:00.000Z',
      cardId: card.id,
    });

    expect(created.cardId).toBe(card.id);
  });

  it('rejects a cardId that does not belong to the requesting user', async () => {
    const otherUsersCard = await cardsService.create(authContext, 'user-2', {
      name: 'Inter',
      brand: 'Visa',
      lastDigits: '4321',
      limitAmount: 3000,
      closingDay: 5,
      dueDay: 12,
    });

    await expect(
      service.create(authContext, 'user-1', {
        title: 'Compra',
        amount: 100,
        type: TransactionType.EXPENSE,
        category: 'Compras',
        occurredAt: '2026-05-05T10:00:00.000Z',
        cardId: otherUsersCard.id,
      }),
    ).rejects.toThrow(NotFoundException);
  });
});
