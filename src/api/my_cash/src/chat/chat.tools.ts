import { Injectable } from '@nestjs/common';
import { CardsService } from '../cards/cards.service';
import { TransactionType } from '../transactions/transaction-type.enum';
import { TransactionsService } from '../transactions/transactions.service';
import type { RepositoryAuthContext } from '../transactions/transactions.repository';
import type { Transaction } from '../transactions/interfaces/transaction.interface';
import type { CreateTransactionDto } from '../transactions/dto/create-transaction.dto';

export interface ToolContext {
  authContext: RepositoryAuthContext;
  /** Always taken from the verified JWT — never from what the model sends. */
  userId: string;
}

/** Categories the app's own composer offers; the AI must stick to them. */
export const INCOME_CATEGORIES = [
  'Salário',
  'Freelance',
  'Vendas',
  'Reembolso',
  'Investimentos',
  'Outros',
];

export const EXPENSE_CATEGORIES = [
  'Alimentação',
  'Moradia',
  'Transporte',
  'Saúde',
  'Educação',
  'Lazer',
  'Assinaturas',
  'Compras',
  'Outros',
];

/** Tools that change data — used to tell the client to reload the dashboard. */
export const WRITE_TOOLS = new Set([
  'create_transaction',
  'update_transaction',
  'delete_transaction',
]);

const period = {
  month: {
    type: 'string',
    description: 'Mês no formato YYYY-MM. Omita para o mês atual.',
  },
  year: { type: 'string', description: 'Ano YYYY, para o ano inteiro.' },
};

const transactionFields = {
  title: { type: 'string', description: 'Descrição curta, ex "Mercado Extra".' },
  amount: { type: 'number', description: 'Valor positivo em reais.' },
  type: { type: 'string', enum: ['income', 'expense'] },
  category: {
    type: 'string',
    description: `Receita: ${INCOME_CATEGORIES.join(', ')}. Despesa: ${EXPENSE_CATEGORIES.join(', ')}.`,
  },
  occurredAt: { type: 'string', description: 'Data YYYY-MM-DD.' },
  notes: { type: 'string' },
  source: {
    type: 'string',
    description:
      'Forma de pagamento. Despesa: "Pix", "Débito", "Crédito", "Dinheiro", ' +
      '"Transferência" ou "Boleto". Receita: "Pix", "Transferência", "Depósito", ' +
      '"Dinheiro" ou "Boleto". Em "Crédito", preencha também cardId.',
  },
  cardId: {
    type: 'string',
    description: 'Id de um cartão de list_cards, quando source é "Crédito".',
  },
  installmentsTotal: {
    type: 'integer',
    description: 'Número de parcelas. amount é o total da compra, não a parcela.',
  },
  recurrenceFrequency: {
    type: 'string',
    enum: ['weekly', 'monthly', 'yearly'],
    description: 'Só para contas que se repetem (assinatura, aluguel, salário).',
  },
};

export const CHAT_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'list_transactions',
      description:
        'Lista as transações do usuário em um período, com id, valor, categoria e data. ' +
        'Use para qualquer pergunta sobre gastos, ganhos, categorias ou histórico, e para ' +
        'achar o id de uma transação antes de editar ou apagar.',
      parameters: {
        type: 'object',
        properties: {
          ...period,
          type: { type: 'string', enum: ['income', 'expense'] },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_summary',
      description:
        'Totais do período: receitas, despesas, saldo e quantidade de lançamentos.',
      parameters: { type: 'object', properties: period },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_cards',
      description: 'Cartões de crédito cadastrados (id, nome, limite, fechamento).',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_transaction',
      description: 'Registra uma nova receita ou despesa.',
      parameters: {
        type: 'object',
        properties: transactionFields,
        required: ['title', 'amount', 'type', 'category', 'occurredAt'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'update_transaction',
      description:
        'Altera uma transação existente. Só os campos informados mudam. ' +
        'Chame apenas depois do usuário confirmar.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Id vindo de list_transactions.' },
          ...transactionFields,
          scope: {
            type: 'string',
            enum: ['this', 'forward'],
            description:
              'Em série recorrente/parcelada: "this" só esta ocorrência, ' +
              '"forward" desta em diante. Padrão "this".',
          },
        },
        required: ['id'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'delete_transaction',
      description:
        'Apaga UMA transação pelo id. Chame apenas depois do usuário confirmar ' +
        'explicitamente, citando o que será apagado.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          scope: { type: 'string', enum: ['this', 'forward'] },
        },
        required: ['id'],
      },
    },
  },
];

type ToolArgs = Record<string, unknown>;

@Injectable()
export class ChatTools {
  constructor(
    private readonly transactionsService: TransactionsService,
    private readonly cardsService: CardsService,
  ) {}

  /**
   * Runs one tool call and returns its JSON result for the model.
   *
   * Everything routes through the same services the HTTP controllers use,
   * with the userId from the verified JWT and the caller's Supabase token —
   * so the model can never reach another user's rows, and payload validation
   * (amount, category, card ownership) is the exact same as a manual entry.
   */
  async run(ctx: ToolContext, name: string, args: ToolArgs): Promise<string> {
    const { authContext, userId } = ctx;

    try {
      switch (name) {
        case 'list_transactions': {
          const rows = await this.transactionsService.findAll(
            authContext,
            userId,
            this.type(args.type),
            this.text(args.month),
            this.text(args.year),
          );
          return this.json(rows.map((row) => this.slim(row)));
        }

        case 'get_summary':
          return this.json(
            await this.transactionsService.getSummary(
              authContext,
              userId,
              this.text(args.month),
              this.text(args.year),
            ),
          );

        case 'list_cards': {
          const cards = await this.cardsService.findAll(authContext, userId);
          return this.json(
            cards.map((card) => ({
              id: card.id,
              name: card.name,
              brand: card.brand,
              limitAmount: card.limitAmount,
              closingDay: card.closingDay,
            })),
          );
        }

        case 'create_transaction': {
          const dto = this.toDto(args) as CreateTransactionDto;
          const creditError = this.creditWithoutCardError(dto);
          if (creditError) return this.json(creditError);
          return this.json(
            this.slim(
              await this.transactionsService.create(authContext, userId, dto),
            ),
          );
        }

        case 'update_transaction': {
          const id = this.text(args.id);
          if (!id) return this.json({ error: 'id é obrigatório' });
          const dto = this.toDto(args);
          const creditError = this.creditWithoutCardError(dto);
          if (creditError) return this.json(creditError);
          return this.json(
            this.slim(
              await this.transactionsService.update(
                authContext,
                userId,
                id,
                dto,
                this.scope(args.scope),
              ),
            ),
          );
        }

        case 'delete_transaction': {
          const id = this.text(args.id);
          if (!id) return this.json({ error: 'id é obrigatório' });
          await this.transactionsService.remove(
            authContext,
            userId,
            id,
            this.scope(args.scope),
          );
          return this.json({ deleted: true, id });
        }

        default:
          return this.json({ error: `ferramenta desconhecida: ${name}` });
      }
    } catch (error) {
      // Tool failures are conversation material, not 500s — the model reports
      // them back to the user and can retry with corrected arguments.
      return this.json({ error: this.messageOf(error) });
    }
  }

  /** Trimmed row: the fields the model actually reasons about. */
  private slim(row: Transaction) {
    return {
      id: row.id,
      title: row.title,
      amount: row.amount,
      type: row.type,
      category: row.category,
      occurredAt: row.occurredAt,
      notes: row.notes,
      source: row.source,
      cardId: row.cardId,
      installmentsTotal: row.installmentsTotal,
      recurrenceFrequency: row.recurrenceFrequency,
    };
  }

  /** Model arguments → DTO, keeping only fields the model is allowed to set. */
  private toDto(args: ToolArgs) {
    const amount = typeof args.amount === 'number' ? args.amount : undefined;
    const installments =
      typeof args.installmentsTotal === 'number'
        ? Math.trunc(args.installmentsTotal)
        : undefined;
    const frequency = this.text(args.recurrenceFrequency);

    return {
      title: this.text(args.title),
      amount,
      type: this.type(args.type),
      category: this.text(args.category),
      occurredAt: this.text(args.occurredAt),
      notes: this.text(args.notes),
      source: this.text(args.source),
      cardId: this.text(args.cardId),
      installmentsTotal: installments,
      recurrenceFrequency: frequency as CreateTransactionDto['recurrenceFrequency'],
    };
  }

  /**
   * A deterministic backstop for the prompt's "call list_cards before
   * create_transaction" rule — the model doesn't always follow it, so a
   * transaction with source "Crédito" and no cardId is rejected here and
   * handed back as tool output the model must react to (call list_cards,
   * then retry), instead of silently saving with no card attached.
   */
  private creditWithoutCardError(dto: {
    source?: string;
    cardId?: string;
  }): { error: string } | null {
    if (dto.source !== 'Crédito' || dto.cardId) return null;
    return {
      error:
        'source é "Crédito" mas cardId não foi informado. Chame list_cards, ' +
        'ache o cartão que o usuário citou e tente de novo com o cardId.',
    };
  }

  private type(value: unknown): TransactionType | undefined {
    return value === 'income' || value === 'expense'
      ? (value as TransactionType)
      : undefined;
  }

  private scope(value: unknown): 'this' | 'forward' | undefined {
    return value === 'this' || value === 'forward' ? value : undefined;
  }

  private text(value: unknown): string | undefined {
    return typeof value === 'string' && value.trim() ? value.trim() : undefined;
  }

  private json(value: unknown): string {
    return JSON.stringify(value);
  }

  private messageOf(error: unknown): string {
    const response = (error as { response?: { message?: unknown } })?.response;
    if (typeof response?.message === 'string') return response.message;
    if (Array.isArray(response?.message)) return response.message.join(', ');
    return error instanceof Error ? error.message : 'falha ao executar';
  }
}
