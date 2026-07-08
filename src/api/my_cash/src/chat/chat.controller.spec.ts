import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ChatController } from './chat.controller';
import { ChatService } from './chat.service';

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
    `data: ${JSON.stringify({ choices: [{ delta: { content } }] })}\n\ndata: [DONE]\n\n`,
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
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) =>
              ({ OPENROUTER_APIKEY: 'test-key', OPENROUTER_MODEL: 'test-model' })[
                key
              ],
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

  it('streams the OpenRouter reply through as plain text and forwards the auth header', async () => {
    const { res, chunks } = makeRes();

    await controller.create(
      { messages: [{ role: 'user', content: 'Comprei um lanche por 30 reais' }] },
      res,
    );

    expect(chunks.join('')).toBe('Anotado!');
    expect(fetchSpy).toHaveBeenCalledWith(
      'https://openrouter.ai/api/v1/chat/completions',
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: 'Bearer test-key' }),
      }),
    );
  });

  it('rejects an empty message list without calling OpenRouter', async () => {
    const { res } = makeRes();

    await expect(controller.create({ messages: [] }, res)).rejects.toThrow();
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
