import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { CardsController } from './cards.controller';
import { SupabaseCardsRepository } from './supabase-cards.repository';
import { CARDS_REPOSITORY } from './cards.repository';
import { CardsService } from './cards.service';

@Module({
  imports: [ConfigModule],
  controllers: [CardsController],
  providers: [
    CardsService,
    {
      provide: CARDS_REPOSITORY,
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

        return new SupabaseCardsRepository(supabaseUrl, supabaseAnonKey);
      },
    },
  ],
  exports: [CardsService],
})
export class CardsModule {}
