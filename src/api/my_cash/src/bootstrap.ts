import type { INestApplication } from '@nestjs/common';

const corsMethods = ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'];
const defaultCorsOrigins = [
  'http://localhost:3000',
  'http://localhost:4200',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:4200',
  'http://10.0.2.2:3000',
];

export function configureApp(app: INestApplication) {
  app.disable('x-powered-by');
  app.setGlobalPrefix('api');
  applySecurityHeaders(app);
  configureCors(app);
}

export function getCorsOptions() {
  const allowedOrigins = process.env.CORS_ORIGIN?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return {
    origin: allowedOrigins?.length ? allowedOrigins : defaultCorsOrigins,
    methods: corsMethods,
    allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'Origin'],
    credentials: false,
    maxAge: 86_400,
  };
}

export function configureCors(app: INestApplication) {
  app.enableCors(getCorsOptions());
}

function applySecurityHeaders(app: INestApplication) {
  app.use((_, response, next) => {
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('X-Frame-Options', 'DENY');
    response.setHeader('Referrer-Policy', 'no-referrer');
    response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
    next();
  });
}