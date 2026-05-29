# Contexto do Projeto: PJ-FINANC

## Visão Geral
Aplicativo de controle financeiro inteligente, focado em facilidade de uso diário através de automação com Inteligência Artificial (LLM). O controle de fluxo principal será mensal, com uma visão alternativa anual.

## Stack Tecnológica e Arquitetura
* **Frontend / Interface:** Flutter (Mobile Android e Web).
* **Backend / API:** Nest.js. (Hospedada no Vercel)
* **Banco de Dados:** Supabase.
* **Auth** Email/senha e Conta Google.
* **Padrão de Arquitetura:** MVVM (aplicado no Flutter).
* **Integração de IA:** OpenRouter (Free) ou Groq para o modelo LLM, e Whisper para transcrição de áudio. Uso de *Vector Search* para buscas e consultas dinâmicas no chat.

## Diretrizes de Desenvolvimento e Qualidade (Pilares do Projeto)
* **Segurança por Padrão (Security-First):** A segurança é um dos objetivos principais e inegociáveis do projeto. Toda a manipulação de dados financeiros, chaves de API, tokens de autenticação (via Supabase) e comunicações entre o app e o backend devem seguir as melhores práticas de proteção e criptografia.
* **Testes Automatizados:** Desde o início, o projeto deve possuir uma cobertura robusta de testes:
    * **No Nest.js:** Testes unitários e de integração para garantir a resiliência das APIs, validações de payload e regras de negócio.
    * **No Flutter:** Testes de unidade, de widget e de integração para validar o comportamento dos ViewModels (MVVM) e o fluxo das telas.
* **Documentação Contínua:** Tudo deve ser rigorosamente documentado desde o princípio do desenvolvimento através de arquivos Markdown (`.md`), cobrindo a arquitetura, diagramas de banco de dados, rotas da API e guias de setup.

## Funcionalidades Core (Gestão Financeira)
* **Entradas:** Salário, transferências (Pix), Rendas Extras.
* **Saídas:** Despesas gerais, Compras Parceladas, Assinaturas (recorrentes).
* **Categorização:**
    * Sistema de separação de categorias de gastos.
    * Permitir a criação de "infinitas" categorias pelo usuário.
    * Disponibilizar uma grande variedade de ícones para personalização.
* **Visualização (Dashboards):** Gráficos simples para facilitar o controle (ex: Gasto por categoria, Gasto por dia, etc.).

## Gestão de Cartões de Crédito
* Controle de faturas.
* Monitoramento das datas de fechamento e vencimento dos cartões.
* **Feature Estratégica:** Indicativo dinâmico de qual é o melhor cartão para utilizar no dia (calculado com base nas datas de fechamento).

## Modo Chat (O "Secretário Financeiro")
* Interface conversacional no estilo WhatsApp, suportando inputs de **Texto e Áudio** (processamento de voz via Whisper).
* A LLM terá capacidade de "Agir" no app (Agentic AI): cadastrar entradas/saídas, dividir parcelas, organizar fluxo, etc.
* **Fluxo de Ação do Chat:**
    1. Usuário informa os dados brutos usando linguagem 100% natural do dia a dia (ex: "Comprei um lanche por 30 reais no crédito").
    2. A IA interpreta e retorna um *Preview* das ações que pretende executar no banco de dados.
    3. O *Preview* é interativo/editável: o usuário pode aprovar, cancelar, editar manualmente na tela, ou responder no chat pedindo para a própria LLM corrigir a ação.
* **Modo Consulta:** O chat atuará também como oráculo dos dados do usuário. O uso de **Vector Search** é vital aqui para garantir precisão na recuperação das informações.

## Notificações, Incentivos e Insights Inteligentes
* **Push Notifications Úteis:** Alertas de fechamento de cartão, lembretes de vencimento de fatura, etc.
* **Insights e Comemorações (AI-Driven):** Tudo gerado de forma inteligente e automatizada (nada de mensagens pré-programadas/estáticas).
    * *Exemplos de Insights:* "Cuidado, seus gastos com cantina estão altos esta semana. Que tal reduzir?"
    * *Exemplos de Comemoração:* "Boa! Você pagou a última parcela da sua TV!"
* **Arquitetura dos Insights:** O backend utilizará "gatilhos" (triggers) para ativar o processamento analítico via API. A LLM será invocada nessa etapa final apenas para interpretar os dados do gatilho e *naturalizar/humanizar* o texto da notificação antes de enviá-la ao usuário.
