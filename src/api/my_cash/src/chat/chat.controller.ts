import { Body, Controller, Post, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import type { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ChatService } from './chat.service';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  async create(@Body() dto: SendMessageDto, @Res() res: Response) {
    await this.chatService.streamReply(dto.messages, res);
  }
}
