import {
  BadRequestException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { CreateCardDto } from './dto/create-card.dto';
import { UpdateCardDto } from './dto/update-card.dto';
import { Card } from './interfaces/card.interface';
import {
  CARDS_REPOSITORY,
  type CardsRepository,
  type RepositoryAuthContext,
} from './cards.repository';

@Injectable()
export class CardsService {
  constructor(
    @Inject(CARDS_REPOSITORY)
    private readonly cardsRepository: CardsRepository,
  ) {}

  async findAll(
    authContext: RepositoryAuthContext,
    userId: string,
  ): Promise<Card[]> {
    return this.cardsRepository.findAll(authContext, userId);
  }

  async findOne(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<Card> {
    return this.cardsRepository.findOne(authContext, userId, id);
  }

  async create(
    authContext: RepositoryAuthContext,
    userId: string,
    dto: CreateCardDto,
  ): Promise<Card> {
    this.assertValidPayload(dto);

    const now = new Date().toISOString();
    const card: Card = {
      id: randomUUID(),
      userId,
      name: dto.name.trim(),
      brand: dto.brand.trim(),
      lastDigits: this.normalizeLastDigits(dto.lastDigits),
      limitAmount: this.normalizeAmount(dto.limitAmount),
      closingDay: this.normalizeDay(dto.closingDay, 'closingDay'),
      dueDay: this.normalizeDay(dto.dueDay, 'dueDay'),
      createdAt: now,
      updatedAt: now,
    };

    return this.cardsRepository.create(authContext, card);
  }

  async update(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
    dto: UpdateCardDto,
  ): Promise<Card> {
    const card = await this.findOne(authContext, userId, id);
    const nextCard = { ...card };

    if (dto.name !== undefined) {
      nextCard.name = this.normalizeRequiredString(dto.name, 'name');
    }

    if (dto.brand !== undefined) {
      nextCard.brand = this.normalizeRequiredString(dto.brand, 'brand');
    }

    if (dto.lastDigits !== undefined) {
      nextCard.lastDigits = this.normalizeLastDigits(dto.lastDigits);
    }

    if (dto.limitAmount !== undefined) {
      nextCard.limitAmount = this.normalizeAmount(dto.limitAmount);
    }

    if (dto.closingDay !== undefined) {
      nextCard.closingDay = this.normalizeDay(dto.closingDay, 'closingDay');
    }

    if (dto.dueDay !== undefined) {
      nextCard.dueDay = this.normalizeDay(dto.dueDay, 'dueDay');
    }

    nextCard.updatedAt = new Date().toISOString();

    return this.cardsRepository.update(authContext, nextCard);
  }

  async remove(
    authContext: RepositoryAuthContext,
    userId: string,
    id: string,
  ): Promise<void> {
    await this.cardsRepository.remove(authContext, userId, id);
  }

  private assertValidPayload(dto: CreateCardDto): void {
    this.normalizeRequiredString(dto.name, 'name');
    this.normalizeRequiredString(dto.brand, 'brand');
    this.normalizeLastDigits(dto.lastDigits);
    this.normalizeAmount(dto.limitAmount);
    this.normalizeDay(dto.closingDay, 'closingDay');
    this.normalizeDay(dto.dueDay, 'dueDay');
  }

  private normalizeRequiredString(value: string, fieldName: string): string {
    if (typeof value !== 'string') {
      throw new BadRequestException(`${fieldName} must be a string`);
    }

    const normalized = value.trim();
    if (!normalized) {
      throw new BadRequestException(`${fieldName} cannot be empty`);
    }

    return normalized;
  }

  private normalizeLastDigits(value: string): string {
    const normalized = this.normalizeRequiredString(value, 'lastDigits');
    if (!/^\d{4}$/.test(normalized)) {
      throw new BadRequestException('lastDigits must have exactly 4 digits');
    }

    return normalized;
  }

  private normalizeAmount(amount: number): number {
    if (typeof amount !== 'number' || Number.isNaN(amount) || amount <= 0) {
      throw new BadRequestException('limitAmount must be a positive number');
    }

    return Number(amount.toFixed(2));
  }

  private normalizeDay(day: number, fieldName: string): number {
    if (
      typeof day !== 'number' ||
      !Number.isInteger(day) ||
      day < 1 ||
      day > 31
    ) {
      throw new BadRequestException(`${fieldName} must be an integer from 1 to 31`);
    }

    return day;
  }
}
