import type { INestApplication } from '@nestjs/common';

const corsMethods = ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'];

export function configureApp(app: INestApplication) {
  app.setGlobalPrefix('api');
  configureCors(app);
}

export function getCorsOptions() {
  const allowedOrigins = process.env.CORS_ORIGIN?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return {
    origin: allowedOrigins?.length ? allowedOrigins : true,
    methods: corsMethods,
  };
}

export function configureCors(app: INestApplication) {
  app.enableCors(getCorsOptions());
}