import { Module } from '@nestjs/common';
import { CardsModule } from '../cards/cards.module';
import { TransactionsModule } from '../transactions/transactions.module';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { ChatTools } from './chat.tools';

@Module({
  imports: [TransactionsModule, CardsModule],
  controllers: [ChatController],
  providers: [ChatService, ChatTools],
})
export class ChatModule {}
