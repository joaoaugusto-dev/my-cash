import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { RateLimitGuard } from '../common/rate-limit.guard';
import { JwtAuthGuard, type AuthenticatedRequest } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  @UseGuards(JwtAuthGuard, new RateLimitGuard({ limit: 60, windowMs: 60_000 }))
  @Get('me')
  me(@Req() request: AuthenticatedRequest) {
    return {
      user: {
        id: request.user.userId,
        email: request.user.email,
        role: request.user.role,
      },
    };
  }
}
