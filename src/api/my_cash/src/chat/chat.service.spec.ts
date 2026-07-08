import { ConfigService } from '@nestjs/config';
import { BadGatewayException, BadRequestException } from '@nestjs/common';
import type { Response } from 'express';
import { ChatService } from './chat.service';

function makeService(config: Record<string, string | undefined>) {
  return new ChatService({
    get: (key: string) => config[key],
  } as unknown as ConfigService);
}

/** A minimal stand-in for express' Response, capturing what streamReply writes. */
function makeRes() {
  const chunks: string[] = [];
  const headers: Record<string, string> = {};
  let statusCode: number | undefined;

  const res = {
    status: (code: number) => {
      statusCode = code;
      return res;
    },
    setHeader: (key: string, value: string) => {
      headers[key] = value;
    },
    write: (chunk: string) => {
      chunks.push(chunk);
      return true;
    },
    end: () => undefined,
  };

  return {
    res: res as unknown as Response,
    chunks,
    headers,
    get statusCode() {
      return statusCode;
    },
  };
}

/** Builds a fetch Response carrying an OpenRouter-shaped SSE body. */
function sseResponse(deltas: string[], status = 200) {
  const body =
    deltas
      .map((content) => `data: ${JSON.stringify({ choices: [{ delta: { content } }] })}\n\n`)
      .join('') + 'data: [DONE]\n\n';
  return new Response(body, { status });
}

describe('ChatService', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('rejects when there is no non-empty message', async () => {
    const service = makeService({
      OPENROUTER_APIKEY: 'key',
      OPENROUTER_MODEL: 'model',
    });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: '   ' }], res),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('fails clearly when the API key is missing from .env', async () => {
    const service = makeService({ OPENROUTER_MODEL: 'model' });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: 'oi' }], res),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });

  it('surfaces a BadGatewayException when OpenRouter responds with an error', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 500 }));
    const service = makeService({
      OPENROUTER_APIKEY: 'key',
      OPENROUTER_MODEL: 'model',
    });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: 'oi' }], res),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });

  it('streams each delta straight through as plain text', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(sseResponse(['Ol', 'á', '!']));
    const service = makeService({
      OPENROUTER_APIKEY: 'key',
      OPENROUTER_MODEL: 'model',
    });
    const mockRes = makeRes();

    await service.streamReply([{ role: 'user', content: 'oi' }], mockRes.res);

    expect(mockRes.chunks.join('')).toBe('Olá!');
    expect(mockRes.headers['Content-Type']).toContain('text/plain');
    expect(mockRes.statusCode).toBe(200);
  });

  it('writes a fallback line when the upstream stream carries no content', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(sseResponse([]));
    const service = makeService({
      OPENROUTER_APIKEY: 'key',
      OPENROUTER_MODEL: 'model',
    });
    const { res, chunks } = makeRes();

    await service.streamReply([{ role: 'user', content: 'oi' }], res);

    expect(chunks.join('')).toContain('Não consegui gerar');
  });

  it('sends only the trimmed, role-valid tail of the history upstream', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(sseResponse(['ok']));
    const service = makeService({
      OPENROUTER_APIKEY: 'key',
      OPENROUTER_MODEL: 'model',
    });
    const { res } = makeRes();

    const longHistory = Array.from({ length: 25 }, (_, i) => ({
      role: 'user' as const,
      content: `msg ${i}`,
    }));
    await service.streamReply(
      [
        ...longHistory,
        { role: 'user', content: '  padded  ' },
        { role: 'system' as never, content: 'should be dropped' },
      ],
      res,
    );

    const requestBody = JSON.parse(
      (fetchSpy.mock.calls[0][1]?.body as string) ?? '{}',
    );
    // system prompt + last 20 valid entries (the invalid "system" role dropped)
    expect(requestBody.messages).toHaveLength(21);
    expect(requestBody.stream).toBe(true);
    expect(requestBody.reasoning).toEqual({ enabled: false });
    expect(requestBody.messages[0].role).toBe('system');
    expect(requestBody.messages.at(-1)).toEqual({
      role: 'user',
      content: 'padded',
    });
  });
});
