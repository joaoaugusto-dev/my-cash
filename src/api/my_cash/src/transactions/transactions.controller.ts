import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import type { CreateTransactionDto } from './dto/create-transaction.dto';
import type { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionType } from './transaction-type.enum';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TransactionsService } from './transactions.service';

@UseGuards(JwtAuthGuard)
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  findAll(
    @Req() request: Request & { user: { userId: string } },
    @Query('type') type?: TransactionType,
    @Query('month') month?: string,
  ) {
    return this.transactionsService.findAll(request.user.userId, type, month);
  }

  @Get('summary')
  getSummary(
    @Req() request: Request & { user: { userId: string } },
    @Query('month') month?: string,
  ) {
    return this.transactionsService.getSummary(request.user.userId, month);
  }

  @Get(':id')
  findOne(@Req() request: Request & { user: { userId: string } }, @Param('id') id: string) {
    return this.transactionsService.findOne(request.user.userId, id);
  }

  @Post()
  create(@Req() request: Request & { user: { userId: string } }, @Body() dto: CreateTransactionDto) {
    return this.transactionsService.create(request.user.userId, dto);
  }

  @Patch(':id')
  update(
    @Req() request: Request & { user: { userId: string } },
    @Param('id') id: string,
    @Body() dto: UpdateTransactionDto,
  ) {
    return this.transactionsService.update(request.user.userId, id, dto);
  }

  @Delete(':id')
  async remove(
    @Req() request: Request & { user: { userId: string } },
    @Param('id') id: string,
  ) {
    await this.transactionsService.remove(request.user.userId, id);

    return { deleted: true, id };
  }
}