import { NestFactory } from '@nestjs/core';
import type { INestApplication } from '@nestjs/common';

import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';

let cachedApp: INestApplication | undefined;
let cachedHandler: ((request: unknown, response: unknown) => unknown) | undefined;

async function getHandler() {
  if (!cachedApp) {
    cachedApp = await NestFactory.create(AppModule);
    configureApp(cachedApp);
    await cachedApp.init();
    cachedHandler = cachedApp.getHttpAdapter().getInstance();
  }

  return cachedHandler;
}

export async function handleRequest(request: unknown, response: unknown) {
  const expressHandler = await getHandler();

  if (!expressHandler) {
    throw new Error('Vercel handler was not initialized');
  }

  return expressHandler(request, response);
}