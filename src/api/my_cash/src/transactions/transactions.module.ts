import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
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
        const supabaseAnonKey = configService.get<string>('SUPABASE_ANON_KEY');

        if (!supabaseUrl) {
          throw new Error('SUPABASE_URL is missing in the backend .env file');
        }

        if (!supabaseAnonKey) {
          throw new Error(
            'SUPABASE_ANON_KEY is missing in the backend .env file',
          );
        }

        return new SupabaseTransactionsRepository(supabaseUrl, supabaseAnonKey);
      },
    },
  ],
  exports: [TransactionsService],
})
export class TransactionsModule {}
