import {
	CanActivate,
	ExecutionContext,
	Injectable,
	UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createPublicKey, type JsonWebKey } from 'crypto';
import { decode, verify } from 'jsonwebtoken';
import type { Request } from 'express';

@Injectable()
export class JwtAuthGuard implements CanActivate {
	constructor(private readonly configService: ConfigService) {}

	async canActivate(context: ExecutionContext): Promise<boolean> {
		const request = context.switchToHttp().getRequest<Request & { user?: unknown }>();
		const token = this.extractBearerToken(request);

		if (!token) {
			throw new UnauthorizedException('Missing Supabase access token');
		}

		const supabaseUrl = this.configService.get<string>('SUPABASE_URL');

		if (!supabaseUrl) {
			throw new UnauthorizedException('SUPABASE_URL is missing in the backend .env file');
		}

		const issuer = `${supabaseUrl.replace(/\/$/, '')}/auth/v1`;
		const publicKey = await this.getPublicKeyFromJwks(supabaseUrl, token);
		const payload = verify(token, publicKey, { issuer }) as Record<string, unknown>;

		if (!payload.sub) {
			throw new UnauthorizedException('Invalid Supabase token payload');
		}

		request.user = {
			userId: payload.sub,
			email: payload.email,
			role: payload.role,
			raw: payload,
		};

		return true;
	}

	private async getPublicKeyFromJwks(supabaseUrl: string, token: string) {
		const decoded = decode(token, { complete: true });

		if (!decoded || typeof decoded !== 'object' || !('header' in decoded)) {
			throw new UnauthorizedException('Invalid Supabase token format');
		}

		const kid = decoded.header.kid;

		if (!kid) {
			throw new UnauthorizedException('Supabase token header is missing kid');
		}

		const jwksUrl = `${supabaseUrl.replace(/\/$/, '')}/auth/v1/.well-known/jwks.json`;
		const response = await fetch(jwksUrl);

		if (!response.ok) {
			throw new UnauthorizedException('Unable to load Supabase signing keys');
		}

		const body = (await response.json()) as { keys?: Array<JsonWebKey & { kid?: string }> };
		const jwk = body.keys?.find((key) => key.kid === kid);

		if (!jwk) {
			throw new UnauthorizedException('Supabase signing key not found');
		}

		return createPublicKey({ key: jwk as JsonWebKey, format: 'jwk' });
	}

	private extractBearerToken(request: Request) {
		const authorization = request.headers.authorization;

		if (!authorization?.startsWith('Bearer ')) {
			return null;
		}

		return authorization.slice('Bearer '.length).trim();
	}
}