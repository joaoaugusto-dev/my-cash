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

  it('uses local development origins when no env var is set', () => {
    expect(getCorsOptions()).toEqual({
      origin: [
        'http://localhost:3000',
        'http://localhost:4200',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:4200',
        'http://10.0.2.2:3000',
      ],
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'Origin'],
      credentials: false,
      maxAge: 86400,
    });
  });

  it('splits and trims configured origins', () => {
    process.env.CORS_ORIGIN = 'https://app.example.com, http://localhost:4200 ';

    expect(getCorsOptions()).toEqual({
      origin: ['https://app.example.com', 'http://localhost:4200'],
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'Origin'],
      credentials: false,
      maxAge: 86400,
    });
  });

  it('configures the api prefix and cors on the app', () => {
    const disable = jest.fn();
    const app = {
      getHttpAdapter: () => ({
        getInstance: () => ({ disable }),
      }),
      setGlobalPrefix: jest.fn(),
      enableCors: jest.fn(),
      use: jest.fn(),
    } as any;

    configureApp(app);

    expect(disable).toHaveBeenCalledWith('x-powered-by');
    expect(app.setGlobalPrefix).toHaveBeenCalledWith('api');
    expect(app.use).toHaveBeenCalledTimes(1);
    expect(app.enableCors).toHaveBeenCalledWith({
      origin: [
        'http://localhost:3000',
        'http://localhost:4200',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:4200',
        'http://10.0.2.2:3000',
      ],
      methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'Origin'],
      credentials: false,
      maxAge: 86400,
    });
  });
});
