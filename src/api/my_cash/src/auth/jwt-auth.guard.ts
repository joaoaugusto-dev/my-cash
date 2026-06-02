import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPublicKey, type KeyObject, type JsonWebKey } from 'crypto';
import { decode, verify } from 'jsonwebtoken';
import type { Request } from 'express';

export interface AuthenticatedUser {
  userId: string;
  email?: string;
  role: 'authenticated';
  accessToken: string;
}

export type AuthenticatedRequest = Request & { user: AuthenticatedUser };

const allowedAlgorithms = ['RS256', 'ES256'] as const;
const expectedAudience = 'authenticated';
const expectedRole = 'authenticated';
const defaultJwksCacheMs = 5 * 60 * 1000;
const maxJwksCacheMs = 10 * 60 * 1000;

interface CachedJwks {
  keys: Array<JsonWebKey & { kid?: string; alg?: string }>;
  expiresAt: number;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  private jwksCache?: CachedJwks;

  constructor(private readonly configService: ConfigService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthenticatedUser }>();
    const token = this.extractBearerToken(request);

    if (!token) {
      throw new UnauthorizedException('Missing Supabase access token');
    }

    const supabaseUrl = this.configService.get<string>('SUPABASE_URL');

    if (!supabaseUrl) {
      throw new UnauthorizedException(
        'SUPABASE_URL is missing in the backend .env file',
      );
    }

    const issuer = `${supabaseUrl.replace(/\/$/, '')}/auth/v1`;
    const publicKey = await this.getPublicKeyFromJwks(supabaseUrl, token);
    let payload: Record<string, unknown>;

    try {
      payload = verify(token, publicKey, {
        issuer,
        audience: expectedAudience,
        algorithms: [...allowedAlgorithms],
      }) as Record<string, unknown>;
    } catch {
      throw new UnauthorizedException('Invalid Supabase access token');
    }

    if (
      typeof payload.sub !== 'string' ||
      !payload.sub ||
      payload.role !== expectedRole
    ) {
      throw new UnauthorizedException('Invalid Supabase token payload');
    }

    request.user = {
      userId: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      role: expectedRole,
      accessToken: token,
    };

    return true;
  }

  private async getPublicKeyFromJwks(
    supabaseUrl: string,
    token: string,
  ): Promise<KeyObject> {
    const decoded = decode(token, { complete: true });

    if (!decoded || typeof decoded !== 'object' || !('header' in decoded)) {
      throw new UnauthorizedException('Invalid Supabase token format');
    }

    const kid = decoded.header.kid;
    const alg = decoded.header.alg;

    if (
      typeof kid !== 'string' ||
      typeof alg !== 'string' ||
      !allowedAlgorithms.includes(alg as (typeof allowedAlgorithms)[number])
    ) {
      throw new UnauthorizedException('Invalid Supabase token header');
    }

    let jwk = (await this.loadJwks(supabaseUrl)).find(
      (key) => key.kid === kid && (!key.alg || key.alg === alg),
    );

    if (!jwk) {
      this.jwksCache = undefined;
      jwk = (await this.loadJwks(supabaseUrl)).find(
        (key) => key.kid === kid && (!key.alg || key.alg === alg),
      );
    }

    if (!jwk) {
      throw new UnauthorizedException('Supabase signing key not found');
    }

    return createPublicKey({ key: jwk as JsonWebKey, format: 'jwk' });
  }

  private async loadJwks(supabaseUrl: string) {
    const now = Date.now();
    if (this.jwksCache && this.jwksCache.expiresAt > now) {
      return this.jwksCache.keys;
    }

    const jwksUrl = `${supabaseUrl.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`;
    const response = await fetch(jwksUrl);

    if (!response.ok) {
      throw new UnauthorizedException('Unable to load Supabase signing keys');
    }

    const body = (await response.json()) as {
      keys?: Array<JsonWebKey & { kid?: string; alg?: string }>;
    };

    if (!Array.isArray(body.keys) || body.keys.length === 0) {
      throw new UnauthorizedException('Supabase signing keys unavailable');
    }

    this.jwksCache = {
      keys: body.keys,
      expiresAt:
        now + this.getCacheDurationMs(response.headers.get('cache-control')),
    };

    return this.jwksCache.keys;
  }

  private getCacheDurationMs(cacheControl: string | null) {
    const maxAge = cacheControl?.match(/max-age=(\d+)/i)?.[1];
    if (!maxAge) {
      return defaultJwksCacheMs;
    }

    return Math.min(Number(maxAge) * 1000, maxJwksCacheMs);
  }

  private extractBearerToken(request: Request) {
    const authorization = request.headers.authorization;

    if (!authorization?.startsWith('Bearer ')) {
      return null;
    }

    return authorization.slice('Bearer '.length).trim();
  }
}
