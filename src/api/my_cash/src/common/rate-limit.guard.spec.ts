import { ExecutionContext, HttpException } from '@nestjs/common';
import { RateLimitGuard } from './rate-limit.guard';

function contextFor(request: { user?: { userId: string }; ip?: string }) {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

describe('RateLimitGuard', () => {
  it('allows requests under the limit and blocks once it is reached', () => {
    const guard = new RateLimitGuard({ limit: 2, windowMs: 60_000 });
    const context = contextFor({ user: { userId: 'user-1' } });

    expect(guard.canActivate(context)).toBe(true);
    expect(guard.canActivate(context)).toBe(true);
    expect(() => guard.canActivate(context)).toThrow(HttpException);
  });

  it('tracks each user independently', () => {
    const guard = new RateLimitGuard({ limit: 1, windowMs: 60_000 });

    expect(guard.canActivate(contextFor({ user: { userId: 'user-1' } }))).toBe(
      true,
    );
    expect(guard.canActivate(contextFor({ user: { userId: 'user-2' } }))).toBe(
      true,
    );
    expect(() =>
      guard.canActivate(contextFor({ user: { userId: 'user-1' } })),
    ).toThrow(HttpException);
  });

  it('resets the count once the window elapses', () => {
    jest.useFakeTimers();
    try {
      const guard = new RateLimitGuard({ limit: 1, windowMs: 1_000 });
      const context = contextFor({ user: { userId: 'user-1' } });

      expect(guard.canActivate(context)).toBe(true);
      expect(() => guard.canActivate(context)).toThrow(HttpException);

      jest.advanceTimersByTime(1_001);

      expect(guard.canActivate(context)).toBe(true);
    } finally {
      jest.useRealTimers();
    }
  });
});
