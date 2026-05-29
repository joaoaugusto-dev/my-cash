import { BadRequestException, NotFoundException } from '@nestjs/common';
import { InMemoryTransactionsRepository } from './in-memory-transactions.repository';
import { TransactionType } from './transaction-type.enum';
import { TransactionsService } from './transactions.service';

describe('TransactionsService', () => {
  let service: TransactionsService;

  beforeEach(() => {
    service = new TransactionsService(new InMemoryTransactionsRepository());
  });

  it('should create and list transactions', async () => {
    const created = await service.create('user-1', {
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
    await expect(service.findAll('user-1')).resolves.toHaveLength(1);
    await expect(service.findAll('user-1', TransactionType.INCOME, '2026-05')).resolves.toHaveLength(1);
  });

  it('should summarize income and expense by month', async () => {
    await service.create('user-1', {
      title: 'Salario',
      amount: 5000,
      type: TransactionType.INCOME,
      category: 'Trabalho',
      occurredAt: '2026-05-01T10:00:00.000Z',
    });

    await service.create('user-1', {
      title: 'Mercado',
      amount: 250.5,
      type: TransactionType.EXPENSE,
      category: 'Alimentacao',
      occurredAt: '2026-05-03T10:00:00.000Z',
    });

    await expect(service.getSummary('user-1', '2026-05')).resolves.toEqual({
      month: '2026-05',
      income: 5000,
      expense: 250.5,
      balance: 4749.5,
      entriesCount: 1,
      exitsCount: 1,
    });
  });

  it('should update and remove transactions', async () => {
    const created = await service.create('user-1', {
      title: 'Lanche',
      amount: 30,
      type: TransactionType.EXPENSE,
      category: 'Alimentacao',
      occurredAt: '2026-05-04T12:00:00.000Z',
    });

    const updated = await service.update('user-1', created.id, {
      amount: 35,
      notes: 'Incluiu bebida',
    });

    expect(updated.amount).toBe(35);
    expect(updated.notes).toBe('Incluiu bebida');

    await service.remove('user-1', created.id);
    await expect(service.findAll('user-1')).resolves.toHaveLength(0);
  });

  it('should reject invalid transactions', async () => {
    await expect(
      service.create('user-1', {
        title: '',
        amount: 10,
        type: TransactionType.INCOME,
        category: 'Teste',
        occurredAt: '2026-05-01T00:00:00.000Z',
      }),
    ).rejects.toThrow(BadRequestException);

    await expect(service.findOne('user-1', 'missing')).rejects.toThrow(NotFoundException);
  });
});