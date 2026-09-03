import { Body, Controller, Post, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import type { SendMessageDto } from './dto/send-message.dto';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { ChatService } from './chat.service';

// ponytail: sem rate limit — o endpoint é fechado por JWT e cada usuário só
// alcança os próprios dados. Se o custo do Gemini virar problema, throttle
// por userId (@nestjs/throttler com storage externo, já que roda serverless).
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  async create(
    @Req() request: AuthenticatedRequest,
    @Body() dto: SendMessageDto,
    @Res() res: Response,
  ) {
    await this.chatService.streamReply(
      dto.messages,
      {
        authContext: { accessToken: request.user.accessToken },
        userId: request.user.userId,
      },
      res,
    );
  }
}
