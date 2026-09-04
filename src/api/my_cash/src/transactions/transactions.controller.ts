import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { CreateTransactionDto } from './dto/create-transaction.dto';
import type { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionType } from './transaction-type.enum';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { RateLimitGuard } from '../common/rate-limit.guard';
import { TransactionsService } from './transactions.service';

// Generous: a dashboard load fires summary + list concurrently, and users
// flip between months/years quickly — this only catches a runaway loop.
@UseGuards(JwtAuthGuard, new RateLimitGuard({ limit: 180, windowMs: 60_000 }))
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  findAll(
    @Req() request: AuthenticatedRequest,
    @Query('type') type?: TransactionType,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    return this.transactionsService.findAll(
      this.authContext(request),
      request.user.userId,
      type,
      month,
      year,
    );
  }

  @Get('summary')
  getSummary(
    @Req() request: AuthenticatedRequest,
    @Query('month') month?: string,
    @Query('year') year?: string,
  ) {
    return this.transactionsService.getSummary(
      this.authContext(request),
      request.user.userId,
      month,
      year,
    );
  }

  @Get(':id')
  findOne(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    return this.transactionsService.findOne(
      this.authContext(request),
      request.user.userId,
      id,
    );
  }

  @Post()
  create(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateTransactionDto,
  ) {
    return this.transactionsService.create(
      this.authContext(request),
      request.user.userId,
      dto,
    );
  }

  @Patch(':id')
  update(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateTransactionDto,
    @Query('scope') scope?: 'this' | 'forward',
  ) {
    return this.transactionsService.update(
      this.authContext(request),
      request.user.userId,
      id,
      dto,
      scope,
    );
  }

  @Delete(':id')
  async remove(
    @Req() request: AuthenticatedRequest,
    @Param('id') id: string,
    @Query('scope') scope?: 'this' | 'forward',
  ) {
    await this.transactionsService.remove(
      this.authContext(request),
      request.user.userId,
      id,
      scope,
    );

    return { deleted: true, id };
  }

  private authContext(request: AuthenticatedRequest) {
    return { accessToken: request.user.accessToken };
  }
}
