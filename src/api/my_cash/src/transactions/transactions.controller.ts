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
import { TransactionsService } from './transactions.service';

@UseGuards(JwtAuthGuard)
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  findAll(
    @Req() request: AuthenticatedRequest,
    @Query('type') type?: TransactionType,
    @Query('month') month?: string,
  ) {
    return this.transactionsService.findAll(
      this.authContext(request),
      request.user.userId,
      type,
      month,
    );
  }

  @Get('summary')
  getSummary(
    @Req() request: AuthenticatedRequest,
    @Query('month') month?: string,
  ) {
    return this.transactionsService.getSummary(
      this.authContext(request),
      request.user.userId,
      month,
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
  ) {
    return this.transactionsService.update(
      this.authContext(request),
      request.user.userId,
      id,
      dto,
    );
  }

  @Delete(':id')
  async remove(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    await this.transactionsService.remove(
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
