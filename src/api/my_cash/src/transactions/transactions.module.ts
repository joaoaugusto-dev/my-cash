import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { createClient } from '@supabase/supabase-js';
import { TransactionsController } from './transactions.controller';
import { SupabaseTransactionsRepository } from './supabase-transactions.repository';
import { TRANSACTIONS_REPOSITORY } from './transactions.repository';
import { TransactionsService } from './transactions.service';

@Module({
  imports: [ConfigModule],
  controllers: [TransactionsController],
  providers: [
    TransactionsService,
    {
      provide: TRANSACTIONS_REPOSITORY,
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const supabaseUrl = configService.get<string>('SUPABASE_URL');
        const supabaseServiceRoleKey = configService.get<string>('SUPABASE_SERVICE_ROLE_KEY');

        if (!supabaseUrl) {
          throw new Error('SUPABASE_URL is missing in the backend .env file');
        }

        if (!supabaseServiceRoleKey) {
          throw new Error('SUPABASE_SERVICE_ROLE_KEY is missing in the backend .env file');
        }

        return new SupabaseTransactionsRepository(
          createClient(supabaseUrl, supabaseServiceRoleKey),
        );
      },
    },
  ],
  exports: [TransactionsService],
})
export class TransactionsModule {}