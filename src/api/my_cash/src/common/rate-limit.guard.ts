import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { Request } from 'express';

interface RateLimitOptions {
  /** Max requests allowed per window, per user (or per IP if unauthenticated). */
  limit: number;
  windowMs: number;
}

type RequestWithUser = Request & { user?: { userId: string } };

/**
 * Per-identity fixed-window limiter, kept in memory on the guard instance.
 * This only works because Vercel reuses the same warm Node process across
 * requests (see api/_shared.ts's cachedApp) — the same trade-off
 * JwtAuthGuard already makes with its JWKS cache. A cold start or scale-out
 * resets counts, so this stops a runaway client loop or one misbehaving
 * account, not a distributed attacker — the right ceiling for a closed beta.
 * Swap for a shared store (a Postgres table, Upstash) if abuse gets past it.
 *
 * Must run after JwtAuthGuard in the guards array so `request.user` is set:
 * `@UseGuards(JwtAuthGuard, new RateLimitGuard({ ... }))`.
 */
export class RateLimitGuard implements CanActivate {
  private readonly hits = new Map<string, { count: number; resetAt: number }>();

  constructor(private readonly options: RateLimitOptions) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const key = request.user?.userId ?? request.ip ?? 'unknown';
    const now = Date.now();

    const entry = this.hits.get(key);
    if (!entry || entry.resetAt <= now) {
      this.hits.set(key, { count: 1, resetAt: now + this.options.windowMs });
      return true;
    }

    if (entry.count >= this.options.limit) {
      throw new HttpException(
        'Muitas requisições em pouco tempo. Aguarde um instante e tente de novo.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    entry.count += 1;
    return true;
  }
}
