import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TransactionType } from './transaction-type.enum';
import { TransactionsController } from './transactions.controller';
import { InMemoryTransactionsRepository } from './in-memory-transactions.repository';
import { TransactionsService } from './transactions.service';

describe('TransactionsController', () => {
  let controller: TransactionsController;
  let service: TransactionsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [TransactionsController],
      providers: [
        {
          provide: TransactionsService,
          useFactory: () =>
            new TransactionsService(new InMemoryTransactionsRepository()),
        },
        {
          provide: JwtAuthGuard,
          useValue: {
            canActivate: () => true,
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: () => 'https://gjlcmjuitapwcdqopqoz.supabase.co',
          },
        },
      ],
    }).compile();

    controller = module.get<TransactionsController>(TransactionsController);
    service = module.get<TransactionsService>(TransactionsService);
  });

  it('should create and fetch transactions through the controller', async () => {
    const request = {
      user: { userId: 'user-1', accessToken: 'test-token' },
    } as never;

    const created = await controller.create(request, {
      title: 'Freelance',
      amount: 1200,
      type: TransactionType.INCOME,
      category: 'Servicos',
      occurredAt: '2026-05-08T09:00:00.000Z',
    });

    expect(created.title).toBe('Freelance');
    await expect(controller.findAll(request)).resolves.toHaveLength(1);
    await expect(
      controller.getSummary(request, '2026-05'),
    ).resolves.toMatchObject({
      income: 1200,
      expense: 0,
      balance: 1200,
    });
  });

  it('should update and delete transactions through the controller', async () => {
    const request = {
      user: { userId: 'user-1', accessToken: 'test-token' },
    } as never;

    const created = await service.create(
      { accessToken: 'test-token' },
      'user-1',
      {
        title: 'Assinatura',
        amount: 49.9,
        type: TransactionType.EXPENSE,
        category: 'Software',
        occurredAt: '2026-05-09T00:00:00.000Z',
      },
    );

    const updated = await controller.update(request, created.id, {
      category: 'Ferramentas',
    });

    expect(updated.category).toBe('Ferramentas');
    await expect(controller.remove(request, created.id)).resolves.toEqual({
      deleted: true,
      id: created.id,
    });
  });
});
