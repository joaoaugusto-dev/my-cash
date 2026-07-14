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

  it('shows a recurring transaction as an occurrence in every following month', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    const july = await service.findAll(
      authContext,
      'user-1',
      undefined,
      '2026-07',
    );

    expect(july).toHaveLength(1);
    expect(july[0].occurredAt).toBe('2026-07-05T00:00:00.000Z');
    expect(july[0].seriesId).toBeTruthy();
  });

  it('deleting "only this month" removes just that occurrence', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    const july = await service.findAll(
      authContext,
      'user-1',
      undefined,
      '2026-07',
    );
    await service.remove(authContext, 'user-1', july[0].id, 'this');

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-07'),
    ).resolves.toHaveLength(0);
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-08'),
    ).resolves.toHaveLength(1);
  });

  it('deleting "this month forward" stops all future occurrences', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    const july = await service.findAll(
      authContext,
      'user-1',
      undefined,
      '2026-07',
    );
    await service.remove(authContext, 'user-1', july[0].id, 'forward');

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-06'),
    ).resolves.toHaveLength(1);
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-07'),
    ).resolves.toHaveLength(0);
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-08'),
    ).resolves.toHaveLength(0);
  });

  it('deletes the anchor once forward-deletion plus exceptions empty out the series', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    // Forward-delete from March on, leaving only Jan and Feb.
    const march = (
      await service.findAll(authContext, 'user-1', undefined, '2026-03')
    )[0];
    await service.remove(authContext, 'user-1', march.id, 'forward');

    // Delete Jan and Feb individually ("this month" scope) — nothing left.
    const jan = (
      await service.findAll(authContext, 'user-1', undefined, '2026-01')
    )[0];
    await service.remove(authContext, 'user-1', jan.id, 'this');
    const feb = (
      await service.findAll(authContext, 'user-1', undefined, '2026-02')
    )[0];
    await service.remove(authContext, 'user-1', feb.id, 'this');

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-01'),
    ).resolves.toHaveLength(0);
    // The anchor itself should be gone, not just its occurrences — findOne
    // on any bare id derived from it would 404 too, but the simplest check
    // is that a full year scan is empty.
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026'),
    ).resolves.toHaveLength(0);
  });

  it('editing a recurring occurrence with "this" scope keeps past months untouched', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    const july = (
      await service.findAll(authContext, 'user-1', undefined, '2026-07')
    )[0];
    await service.update(
      authContext,
      'user-1',
      july.id,
      { amount: 1800 },
      'this',
    );

    const january = (
      await service.findAll(authContext, 'user-1', undefined, '2026-01')
    )[0];
    const newJuly = (
      await service.findAll(authContext, 'user-1', undefined, '2026-07')
    )[0];
    const august = (
      await service.findAll(authContext, 'user-1', undefined, '2026-08')
    )[0];

    expect(january.amount).toBe(1500);
    expect(newJuly.amount).toBe(1800);
    expect(newJuly.seriesId).toBeUndefined(); // now a standalone transaction
    expect(august.amount).toBe(1500);
  });

  it('editing a recurring occurrence with "forward" scope keeps past months untouched', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    const july = (
      await service.findAll(authContext, 'user-1', undefined, '2026-07')
    )[0];
    await service.update(
      authContext,
      'user-1',
      july.id,
      { amount: 1800 },
      'forward',
    );

    const june = (
      await service.findAll(authContext, 'user-1', undefined, '2026-06')
    )[0];
    const newJuly = (
      await service.findAll(authContext, 'user-1', undefined, '2026-07')
    )[0];
    const august = (
      await service.findAll(authContext, 'user-1', undefined, '2026-08')
    )[0];

    expect(june.amount).toBe(1500);
    expect(newJuly.amount).toBe(1800);
    expect(august.amount).toBe(1800);
  });

  it('deleting any installment removes the whole purchase, past parcelas included', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Notebook',
      amount: 3000,
      type: TransactionType.EXPENSE,
      category: 'Compras',
      occurredAt: '2026-01-10T00:00:00.000Z',
      installmentsTotal: 3,
    });

    const february = (
      await service.findAll(authContext, 'user-1', undefined, '2026-02')
    )[0];
    await service.remove(authContext, 'user-1', february.id, 'this');

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-01'),
    ).resolves.toHaveLength(0);
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-03'),
    ).resolves.toHaveLength(0);
  });

  it('turning recurrence off via update stops future occurrences', async () => {
    const created = await service.create(authContext, 'user-1', {
      title: 'Aluguel',
      amount: 1500,
      type: TransactionType.EXPENSE,
      category: 'Moradia',
      occurredAt: '2026-01-05T00:00:00.000Z',
      recurrenceFrequency: 'monthly',
    });

    await service.update(authContext, 'user-1', created.id, {
      recurrenceFrequency: null,
    });

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-07'),
    ).resolves.toHaveLength(0);
    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-01'),
    ).resolves.toHaveLength(1);
  });

  it('stores an installment purchase as a single row split across months', async () => {
    const created = await service.create(authContext, 'user-1', {
      title: 'Notebook',
      amount: 3000,
      type: TransactionType.EXPENSE,
      category: 'Compras',
      occurredAt: '2026-01-10T00:00:00.000Z',
      installmentsTotal: 3,
    });

    expect(created.installmentsTotal).toBe(3);
    expect(created.recurrenceFrequency).toBe('monthly');

    const january = await service.findAll(
      authContext,
      'user-1',
      undefined,
      '2026-01',
    );
    expect(january).toHaveLength(1);
    expect(january[0].amount).toBe(1000);
    expect(january[0].title).toBe('Notebook (1/3)');

    const march = await service.findAll(
      authContext,
      'user-1',
      undefined,
      '2026-03',
    );
    expect(march[0].title).toBe('Notebook (3/3)');

    await expect(
      service.findAll(authContext, 'user-1', undefined, '2026-04'),
    ).resolves.toHaveLength(0);
  });

  it('splits an odd total so the remainder lands on the last installment', async () => {
    await service.create(authContext, 'user-1', {
      title: 'Presente',
      amount: 100,
      type: TransactionType.EXPENSE,
      category: 'Compras',
      occurredAt: '2026-01-10T00:00:00.000Z',
      installmentsTotal: 3,
    });

    const amounts = [
      (await service.findAll(authContext, 'user-1', undefined, '2026-01'))[0]
        .amount,
      (await service.findAll(authContext, 'user-1', undefined, '2026-02'))[0]
        .amount,
      (await service.findAll(authContext, 'user-1', undefined, '2026-03'))[0]
        .amount,
    ];

    expect(amounts).toEqual([33.33, 33.33, 33.34]);
  });

  it('rejects an installmentsTotal outside the 2-36 range', async () => {
    await expect(
      service.create(authContext, 'user-1', {
        title: 'Notebook',
        amount: 3000,
        type: TransactionType.EXPENSE,
        category: 'Compras',
        occurredAt: '2026-01-10T00:00:00.000Z',
        installmentsTotal: 1,
      }),
    ).rejects.toThrow(BadRequestException);
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
