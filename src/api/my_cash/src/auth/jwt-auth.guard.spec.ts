import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { generateKeyPairSync } from 'crypto';
import { sign, type SignOptions } from 'jsonwebtoken';
import { JwtAuthGuard } from './jwt-auth.guard';

const supabaseUrl = 'https://project.supabase.co';
const issuer = `${supabaseUrl}/auth/v1`;
const audience = 'authenticated';
const keyId = 'test-key';

describe('JwtAuthGuard', () => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const publicJwk = {
    ...publicKey.export({ format: 'jwk' }),
    kid: keyId,
    alg: 'RS256',
  };

  let guard: JwtAuthGuard;
  let request: { headers: Record<string, string>; user?: unknown };

  beforeEach(() => {
    guard = new JwtAuthGuard({
      get: (key: string) => (key === 'SUPABASE_URL' ? supabaseUrl : undefined),
    } as ConfigService);
    request = { headers: {} };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: new Headers({ 'cache-control': 'max-age=600' }),
      json: async () => ({ keys: [publicJwk] }),
    } as Response);
  });

  it('accepts a valid Supabase access token', async () => {
    request.headers.authorization = `Bearer ${token()}`;

    await expect(guard.canActivate(context())).resolves.toBe(true);

    expect(request.user).toEqual({
      userId: 'user-1',
      email: 'user@example.com',
      role: 'authenticated',
      accessToken: expect.any(String),
    });
    expect(request.user).not.toHaveProperty('raw');
  });

  it('rejects missing, malformed, and expired tokens', async () => {
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );

    request.headers.authorization = 'Bearer not-a-token';
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );

    request.headers.authorization = `Bearer ${token({ expiresIn: -10 })}`;
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects issuer, audience, subject, and role mismatches', async () => {
    request.headers.authorization = `Bearer ${token({ issuer: 'https://evil.example.com/auth/v1' })}`;
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );

    request.headers.authorization = `Bearer ${token({ audience: 'anon' })}`;
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );

    request.headers.authorization = `Bearer ${token({ subject: null })}`;
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );

    request.headers.authorization = `Bearer ${token({ role: 'anon' })}`;
    await expect(guard.canActivate(context())).rejects.toThrow(
      UnauthorizedException,
    );
  });

  function token(
    options: {
      audience?: string;
      expiresIn?: number;
      issuer?: string;
      role?: string;
      subject?: string | null;
    } = {},
  ) {
    const signOptions: SignOptions = {
      algorithm: 'RS256',
      keyid: keyId,
      audience: options.audience ?? audience,
      expiresIn: options.expiresIn ?? 60,
      issuer: options.issuer ?? issuer,
    };

    if (options.subject !== null) {
      signOptions.subject = options.subject ?? 'user-1';
    }

    return sign(
      {
        email: 'user@example.com',
        role: options.role ?? 'authenticated',
      },
      privateKey,
      signOptions,
    );
  }

  function context() {
    return {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
    } as unknown as ExecutionContext;
  }
});
