import { BadGatewayException, BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Response } from 'express';
import type { ChatMessageDto } from './dto/send-message.dto';

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// Caps how much history is forwarded per request — a long-running
// conversation shouldn't grow the prompt (and the bill) without bound.
const MAX_HISTORY = 20;

const SYSTEM_PROMPT =
  'Você é o assistente financeiro do MyCash. Converse em português do Brasil, ' +
  'de forma natural, curta e direta. Você ainda não tem acesso aos dados ' +
  'financeiros do usuário (transações, cartões, saldo) — essa integração ' +
  'chega em uma próxima etapa. Se perguntarem algo que dependa desses dados, ' +
  'diga que essa parte ainda está a caminho em vez de inventar números.';

const FALLBACK_REPLY = 'Não consegui gerar uma resposta agora. Tente novamente.';

interface OpenRouterStreamChunk {
  choices?: Array<{ delta?: { content?: string } }>;
}

@Injectable()
export class ChatService {
  constructor(private readonly configService: ConfigService) {}

  /**
   * Proxies OpenRouter's SSE stream, writing each generated text delta
   * straight to [res] as plain text chunks — the client just appends bytes
   * as they arrive, no SSE/JSON framing to parse on that side.
   */
  async streamReply(messages: ChatMessageDto[], res: Response): Promise<void> {
    const history = this.normalizeMessages(messages);
    if (history.length === 0) {
      throw new BadRequestException('messages must include at least one entry');
    }

    const apiKey = this.configService.get<string>('OPENROUTER_APIKEY');
    const model = this.configService.get<string>('OPENROUTER_MODEL');
    if (!apiKey || !model) {
      throw new BadGatewayException(
        'OPENROUTER_APIKEY/OPENROUTER_MODEL is missing in the backend .env file',
      );
    }

    const upstream = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        stream: true,
        // Some free models (e.g. reasoning ones) emit a silent "thinking"
        // phase before any visible content — off, so the stream starts
        // writing immediately instead of pausing on hidden reasoning tokens.
        reasoning: { enabled: false },
        messages: [{ role: 'system', content: SYSTEM_PROMPT }, ...history],
      }),
    });

    if (!upstream.ok || !upstream.body) {
      throw new BadGatewayException(
        `OpenRouter request failed (${upstream.status})`,
      );
    }

    res.status(200);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache');

    let wroteAny = false;
    const reader = upstream.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        let newlineIndex: number;
        while ((newlineIndex = buffer.indexOf('\n')) !== -1) {
          const line = buffer.slice(0, newlineIndex).trim();
          buffer = buffer.slice(newlineIndex + 1);
          const delta = this.parseSseDelta(line);
          if (delta) {
            res.write(delta);
            wroteAny = true;
          }
        }
      }
    } finally {
      if (!wroteAny) {
        res.write(FALLBACK_REPLY);
      }
      res.end();
    }
  }

  /** Extracts the text delta from one SSE line, or null if there is none. */
  private parseSseDelta(line: string): string | null {
    if (!line.startsWith('data:')) {
      return null;
    }

    const data = line.slice('data:'.length).trim();
    if (data === '[DONE]' || data === '') {
      return null;
    }

    try {
      const parsed = JSON.parse(data) as OpenRouterStreamChunk;
      return parsed.choices?.[0]?.delta?.content ?? null;
    } catch {
      // Malformed/partial SSE fragment — skip it rather than crash the stream.
      return null;
    }
  }

  private normalizeMessages(messages: ChatMessageDto[]): ChatMessageDto[] {
    if (!Array.isArray(messages)) {
      return [];
    }

    return messages
      .filter(
        (m) =>
          (m?.role === 'user' || m?.role === 'assistant') &&
          typeof m.content === 'string' &&
          m.content.trim().length > 0,
      )
      .map((m) => ({ role: m.role, content: m.content.trim() }))
      .slice(-MAX_HISTORY);
  }
}
