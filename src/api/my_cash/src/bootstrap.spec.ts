import { beforeEach, afterEach, describe, expect, it } from '@jest/globals';

import { configureApp, getCorsOptions } from './bootstrap';

describe('getCorsOptions', () => {
  const originalCorsOrigin = process.env.CORS_ORIGIN;

  beforeEach(() => {
    delete process.env.CORS_ORIGIN;
  });

  afterEach(() => {
    if (originalCorsOrigin === undefined) {
      delete process.env.CORS_ORIGIN;
      return;
    }

    process.env.CORS_ORIGIN = originalCorsOrigin;
  });

  it('allows every origin when no env var is set', () => {
    expect(getCorsOptions()).toEqual({
      origin: true,
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    });
  });

  it('splits and trims configured origins', () => {
    process.env.CORS_ORIGIN = 'https://app.example.com, http://localhost:4200 ';

    expect(getCorsOptions()).toEqual({
      origin: ['https://app.example.com', 'http://localhost:4200'],
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    });
  });

  it('configures the api prefix and cors on the app', () => {
    const app = {
      setGlobalPrefix: jest.fn(),
      enableCors: jest.fn(),
    } as any;

    configureApp(app);

    expect(app.setGlobalPrefix).toHaveBeenCalledWith('api');
    expect(app.enableCors).toHaveBeenCalledWith({
      origin: true,
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    });
  });
});