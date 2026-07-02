import { BadRequestException, NotFoundException } from '@nestjs/common';
import { InMemoryCardsRepository } from './in-memory-cards.repository';
import { CardsService } from './cards.service';

describe('CardsService', () => {
  let service: CardsService;
  const authContext = { accessToken: 'test-token' };

  beforeEach(() => {
    service = new CardsService(new InMemoryCardsRepository());
  });

  it('should create and list cards', async () => {
    const created = await service.create(authContext, 'user-1', {
      name: 'Nubank',
      brand: 'Mastercard',
      lastDigits: '1234',
      limitAmount: 5000,
      closingDay: 10,
      dueDay: 17,
    });

    expect(created.id).toBeTruthy();
    expect(created.userId).toBe('user-1');
    expect(created.lastDigits).toBe('1234');
    await expect(service.findAll(authContext, 'user-1')).resolves.toHaveLength(
      1,
    );
  });

  it('should reject invalid payloads', async () => {
    await expect(
      service.create(authContext, 'user-1', {
        name: 'Nubank',
        brand: 'Mastercard',
        lastDigits: '12',
        limitAmount: 5000,
        closingDay: 10,
        dueDay: 17,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      service.create(authContext, 'user-1', {
        name: 'Nubank',
        brand: 'Mastercard',
        lastDigits: '1234',
        limitAmount: -5,
        closingDay: 10,
        dueDay: 17,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      service.create(authContext, 'user-1', {
        name: 'Nubank',
        brand: 'Mastercard',
        lastDigits: '1234',
        limitAmount: 5000,
        closingDay: 40,
        dueDay: 17,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('should update and delete cards', async () => {
    const created = await service.create(authContext, 'user-1', {
      name: 'Nubank',
      brand: 'Mastercard',
      lastDigits: '1234',
      limitAmount: 5000,
      closingDay: 10,
      dueDay: 17,
    });

    const updated = await service.update(authContext, 'user-1', created.id, {
      limitAmount: 6000,
    });

    expect(updated.limitAmount).toBe(6000);

    await service.remove(authContext, 'user-1', created.id);
    await expect(
      service.findOne(authContext, 'user-1', created.id),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
