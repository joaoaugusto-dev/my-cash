import { ConfigService } from '@nestjs/config';
import { BadGatewayException, BadRequestException } from '@nestjs/common';
import type { Response } from 'express';
import { ChatService, REFRESH_MARKER } from './chat.service';
import type { ChatTools } from './chat.tools';

const ctx = {
  authContext: { accessToken: 'token' },
  userId: 'user-1',
};

function makeService(
  config: Record<string, string | undefined>,
  tools: Partial<ChatTools> = {},
) {
  return new ChatService(
    { get: (key: string) => config[key] } as unknown as ConfigService,
    { run: jest.fn().mockResolvedValue('{}'), ...tools } as unknown as ChatTools,
  );
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

/** Builds a fetch Response carrying a Gemini-shaped SSE body, one chunk per part. */
function sseResponse(parts: unknown[], status = 200) {
  const body = parts
    .map(
      (part) =>
        `data: ${JSON.stringify({ candidates: [{ content: { parts: [part] } }] })}\n\n`,
    )
    .join('');
  return new Response(body, { status });
}

function textSseResponse(deltas: string[], status = 200) {
  return sseResponse(
    deltas.map((text) => ({ text })),
    status,
  );
}

/** SSE body where the model asks for a tool. */
function toolCallResponse(name: string, args: Record<string, unknown>) {
  return sseResponse([{ functionCall: { name, args } }]);
}

describe('ChatService', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('rejects when there is no non-empty message', async () => {
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: '   ' }], ctx, res),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('fails clearly when the API key is missing from .env', async () => {
    const service = makeService({ GEMINI_MODEL: 'model' });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: 'oi' }], ctx, res),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });

  it('surfaces a BadGatewayException when Gemini responds with an error', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 500 }));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res } = makeRes();

    await expect(
      service.streamReply([{ role: 'user', content: 'oi' }], ctx, res),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });

  it('streams each delta straight through as plain text', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(textSseResponse(['Ol', 'á', '!']));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const mockRes = makeRes();

    await service.streamReply([{ role: 'user', content: 'oi' }], ctx, mockRes.res);

    expect(mockRes.chunks.join('')).toBe('Olá!');
    expect(mockRes.headers['Content-Type']).toContain('text/plain');
    expect(mockRes.statusCode).toBe(200);
  });

  it('writes a fallback line when the upstream stream carries no content', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(textSseResponse([]));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res, chunks } = makeRes();

    await service.streamReply([{ role: 'user', content: 'oi' }], ctx, res);

    expect(chunks.join('')).toContain('Não consegui gerar');
  });

  it('sends only the trimmed, role-valid tail of the history upstream', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(textSseResponse(['ok']));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
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
      ctx,
      res,
    );

    const requestBody = JSON.parse(
      (fetchSpy.mock.calls[0][1]?.body as string) ?? '{}',
    );
    // last 20 valid entries (the invalid "system" role dropped)
    expect(requestBody.contents).toHaveLength(20);
    expect(requestBody.systemInstruction.parts[0].text).toContain('MyCash');
    expect(requestBody.contents.at(-1)).toEqual({
      role: 'user',
      parts: [{ text: 'padded' }],
    });
    expect((fetchSpy.mock.calls[0][0] as string)).toContain(
      'https://generativelanguage.googleapis.com/v1beta/models/model:streamGenerateContent',
    );
  });

  it('runs a requested tool with the caller identity and feeds the result back', async () => {
    const run = jest.fn().mockResolvedValue('{"id":"tx-1"}');
    const fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(
        toolCallResponse('create_transaction', { title: 'Mercado', amount: 50 }),
      )
      .mockResolvedValueOnce(textSseResponse(['Registrado!']));
    const service = makeService(
      { GEMINI_APIKEY: 'key', GEMINI_MODEL: 'model' },
      { run },
    );
    const { res, chunks } = makeRes();

    await service.streamReply([{ role: 'user', content: 'gastei 50' }], ctx, res);

    expect(run).toHaveBeenCalledWith(ctx, 'create_transaction', {
      title: 'Mercado',
      amount: 50,
    });
    // A write tool ran, so the client is told to reload the dashboard.
    expect(chunks.join('')).toBe(`Registrado!${REFRESH_MARKER}`);

    const followUp = JSON.parse(
      (fetchSpy.mock.calls[1][1]?.body as string) ?? '{}',
    );
    expect(followUp.contents.at(-1)).toEqual({
      role: 'function',
      parts: [
        {
          functionResponse: {
            name: 'create_transaction',
            response: { result: { id: 'tx-1' } },
          },
        },
      ],
    });
  });

  it('does not signal a refresh for read-only tools', async () => {
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(toolCallResponse('get_summary', {}))
      .mockResolvedValueOnce(textSseResponse(['Você gastou R$ 50.']));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res, chunks } = makeRes();

    await service.streamReply([{ role: 'user', content: 'quanto gastei?' }], ctx, res);

    expect(chunks.join('')).toBe('Você gastou R$ 50.');
  });

  it('forwards inline media and drops parts that are not base64 data', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(textSseResponse(['ok']));
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res } = makeRes();

    await service.streamReply(
      [
        {
          role: 'user',
          content: [
            { type: 'text', text: 'segue a nota' },
            { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,AAAA' } },
            // Remote URL: would make the provider fetch an arbitrary address.
            { type: 'image_url', image_url: { url: 'https://evil.test/a.png' } },
            { type: 'input_audio', input_audio: { data: 'BBBB', format: 'wav' } },
          ],
        },
      ],
      ctx,
      res,
    );

    const body = JSON.parse((fetchSpy.mock.calls[0][1]?.body as string) ?? '{}');
    expect(body.contents.at(-1).parts).toEqual([
      { text: 'segue a nota' },
      { inlineData: { mimeType: 'image/jpeg', data: 'AAAA' } },
      { inlineData: { mimeType: 'audio/wav', data: 'BBBB' } },
    ]);
  });

  it('rejects media above the request cap instead of calling Gemini', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch');
    const service = makeService({
      GEMINI_APIKEY: 'key',
      GEMINI_MODEL: 'model',
    });
    const { res } = makeRes();

    await expect(
      service.streamReply(
        [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${'A'.repeat(4_100_000)}`,
                },
              },
            ],
          },
        ],
        ctx,
        res,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
