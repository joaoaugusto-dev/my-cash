import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CardsController } from './cards.controller';
import { InMemoryCardsRepository } from './in-memory-cards.repository';
import { CardsService } from './cards.service';

describe('CardsController', () => {
  let controller: CardsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CardsController],
      providers: [
        {
          provide: CardsService,
          useFactory: () => new CardsService(new InMemoryCardsRepository()),
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

    controller = module.get<CardsController>(CardsController);
  });

  it('should create, list, update and delete cards through the controller', async () => {
    const request = {
      user: { userId: 'user-1', accessToken: 'test-token' },
    } as never;

    const created = await controller.create(request, {
      name: 'Nubank',
      brand: 'Mastercard',
      lastDigits: '1234',
      limitAmount: 5000,
      closingDay: 10,
      dueDay: 17,
    });

    expect(created.name).toBe('Nubank');
    await expect(controller.findAll(request)).resolves.toHaveLength(1);

    const updated = await controller.update(request, created.id, {
      name: 'Nubank Ultravioleta',
    });
    expect(updated.name).toBe('Nubank Ultravioleta');

    await expect(controller.remove(request, created.id)).resolves.toEqual({
      deleted: true,
      id: created.id,
    });
  });
});
