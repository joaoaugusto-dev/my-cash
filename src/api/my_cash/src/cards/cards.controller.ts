import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { CreateCardDto } from './dto/create-card.dto';
import type { UpdateCardDto } from './dto/update-card.dto';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { RateLimitGuard } from '../common/rate-limit.guard';
import { CardsService } from './cards.service';

// Cards change rarely; this only catches a runaway loop or scripted abuse.
@UseGuards(JwtAuthGuard, new RateLimitGuard({ limit: 120, windowMs: 60_000 }))
@Controller('cards')
export class CardsController {
  constructor(private readonly cardsService: CardsService) {}

  @Get()
  findAll(@Req() request: AuthenticatedRequest) {
    return this.cardsService.findAll(
      this.authContext(request),
      request.user.userId,
    );
  }

  @Get(':id')
  findOne(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.cardsService.findOne(
      this.authContext(request),
      request.user.userId,
      id,
    );
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Body() dto: CreateCardDto) {
    return this.cardsService.create(
      this.authContext(request),
      request.user.userId,
      dto,
    );
  }

  @Patch(':id')
  update(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateCardDto,
  ) {
    return this.cardsService.update(
      this.authContext(request),
      request.user.userId,
      id,
      dto,
    );
  }

  @Delete(':id')
  async remove(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    await this.cardsService.remove(
      this.authContext(request),
      request.user.userId,
      id,
    );

    return { deleted: true, id };
  }

  private authContext(request: AuthenticatedRequest) {
    return { accessToken: request.user.accessToken };
  }
}
