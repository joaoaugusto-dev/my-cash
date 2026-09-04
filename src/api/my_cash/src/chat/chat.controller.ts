import { Body, Controller, Post, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import type { SendMessageDto } from './dto/send-message.dto';
import {
  JwtAuthGuard,
  type AuthenticatedRequest,
} from '../auth/jwt-auth.guard';
import { RateLimitGuard } from '../common/rate-limit.guard';
import { ChatService } from './chat.service';

// Tighter limit than the CRUD endpoints — each message can trigger several
// Gemini calls (tool rounds), so this is the one that protects API cost.
// 20/min is well above a real conversation's pace.
@UseGuards(JwtAuthGuard, new RateLimitGuard({ limit: 20, windowMs: 60_000 }))
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
