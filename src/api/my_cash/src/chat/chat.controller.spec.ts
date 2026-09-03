import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';
import { ChatTools } from './chat.tools';

/** Stands in for the JWT-populated request the guard would provide. */
const request = {
  user: { userId: 'user-1', role: 'authenticated', accessToken: 'token' },
} as never;

function makeRes() {
  const chunks: string[] = [];
  const res = {
    status: () => res,
    setHeader: () => undefined,
    write: (chunk: string) => {
      chunks.push(chunk);
      return true;
    },
    end: () => undefined,
  };
  return { res: res as unknown as Response, chunks };
}

function sseResponse(content: string, status = 200) {
  return new Response(
    `data: ${JSON.stringify({ candidates: [{ content: { parts: [{ text: content }] } }] })}\n\n`,
    { status },
  );
}

describe('ChatController', () => {
  let controller: ChatController;
  let fetchSpy: jest.SpiedFunction<typeof fetch>;

  beforeEach(async () => {
    fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(sseResponse('Anotado!'));

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ChatController],
      providers: [
        ChatService,
        { provide: ChatTools, useValue: { run: jest.fn() } },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) =>
              ({ GEMINI_APIKEY: 'test-key', GEMINI_MODEL: 'test-model' })[key],
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<ChatController>(ChatController);
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });

  it('streams the Gemini reply through as plain text', async () => {
    const { res, chunks } = makeRes();

    await controller.create(
      request,
      { messages: [{ role: 'user', content: 'Comprei um lanche por 30 reais' }] },
      res,
    );

    expect(chunks.join('')).toBe('Anotado!');
    expect(fetchSpy).toHaveBeenCalledWith(
      expect.stringContaining(
        'https://generativelanguage.googleapis.com/v1beta/models/test-model:streamGenerateContent',
      ),
      expect.objectContaining({
        headers: expect.objectContaining({ 'Content-Type': 'application/json' }),
      }),
    );
  });

  it('rejects an empty message list without calling Gemini', async () => {
    const { res } = makeRes();

    await expect(
      controller.create(request, { messages: [] }, res),
    ).rejects.toThrow();
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
