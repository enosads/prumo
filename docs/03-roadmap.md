# Prumo — Roadmap de Desenvolvimento

> **Status**: Ativo · **Versão**: 1.1 · **Data**: 2026-08-18

---

## 📌 Fase 0 — Fundação, Multi-Tenancy & Infraestrutura Base ✅
- [x] Blueprint Arquitetural e Análise de Referência (`/Users/enosads/www/personal/ibc`).
- [x] Docker Compose com PostgreSQL 18 e Redis (porta 5434 e 6380).
- [x] Migrations DDL completas (`0001_initial_schema.up.sql`) e queries SQL com `sqlc`.
- [x] Quality gate `cmd/sqlcprepare` (55 queries validadas contra o Postgres).
- [x] Servidor HTTP Go com Chi + Huma v2 OpenAPI 3.0 e middlewares de autenticação e RBAC.
- [x] Endpoints de autenticação (`/v1/auth/register`, `/v1/auth/login`, `/v1/auth/me`), famílias e contas.
- [x] Scaffolding do App iOS SwiftUI via XcodeGen (`project.yml`), `Brand.swift`, `APIClient.swift`, `AuthSession.swift`.
- [x] Automação do Smoke Test E2E (`scripts/smoke.sh`) com 10 asserções de integridade e segurança.

---

## 🚀 Fase 1 — MVP Fluxo de Caixa, Cartões & Orçamento Familiar ✅
- [x] **Fatia 1.1: Gestão de Contas, Categorias & Lançamento Rápido**
  - Cadastro de categorias e transações (receitas/despesas/transferências).
  - Tela de Extrato no iOS com agrupamento diário, busca instantânea e filtros por membro da família.
  - Modal de Lançamento Rápido (`NewTransactionSheet`) com `CampoMonetario` e criação de contas (`NewAccountSheet`).
- [x] **Fatia 1.2: Cartões de Crédito, Faturas e Parcelamentos Mês a Mês**
  - Controle de limite, faturas e liquidação com débito em conta corrente.
  - Projeção de faturas dos próximos 12 meses com divisão por portador do cartão.
  - Motor de antecipação com desconto a valor presente ($PV = \frac{FV}{(1+i)^n}$).
  - Telas iOS: Carrossel de cartões, detalhes da fatura e sheet de antecipação.
- [x] **Fatia 1.3: Orçamentos por Envelope e Metas de Economia**
  - Envelopes mensais por categoria com cálculo de realizado vs. orçado e valor "Livre para Investir".
  - Tela iOS com transição de cor (Verde <75%, Âmbar 75-100%, Vermelho >100%) e sheet de configuração.
- [x] **Infraestrutura & Deploy Isolado**:
  - Cluster PostgreSQL dedicado `prumo-db` no Fly.io.
  - App `dev.enosads.prumo` instalado e rodando no iPhone físico.
  - 26/26 asserções E2E passando com 100% de sucesso.
  - PR #3 aprovada e mergeada na `main`.

---

## 🧠 Fase 2 — Agente de IA Nativo, Function Calling & Taxonomia Calends (Atual)
- **Fatia 2.1: Taxonomia Enriquecida (13 Roots) & Orquestrador de IA**
  - Alinhamento da taxonomia de categorias do Calends (13 raízes semânticas com slugs imutáveis em inglês + subcategorias).
  - Categoria de sistema `uncategorized` como inbox transitório para OCR/IA.
  - Orquestrador de IA com adapters para Anthropic Claude, OpenAI e Gemini.
  - Streaming SSE para o app iOS e ferramentas (*tools*) de leitura (`get_consolidated_net_worth`, `query_cash_flow`, `get_budget_status`, `get_card_projections`).
- **Fatia 2.2: Execução de Ações Financeiras, Modos de Operação & Audit Trail**
  - Dois modos operacionais: **Modo Confirmação** (cards de aprovação *Human-in-the-Loop* no chat SwiftUI) e **Modo Autônomo** (*act without asking* para tarefas de baixo risco).
  - Trilha de auditoria imutável (`ai_action_audits`) com mecanismo de **Desfazer (Undo) até 30 dias**.
  - Tokenização de PII em memória antes do envio para LLM cloud e controle de hard cap de custos (burn cap).

---

## 📈 Fase 3 — Módulo de Investimentos, Preço Médio & Tese Consultiva
- **Fatia 3.1: Carteiras B3, Global & Renda Fixa**
  - Registro de ordens de compra/venda com cálculo transacional de Preço Médio e Custo Total.
- **Fatia 3.2: Cotações EOD e Consultora de Investimentos**
  - Ingestão de cotações e proventos.
  - Ferramenta da IA que analisa desvios em relação à tese da família e orienta novos aportes.

---

## 🔄 Fase 4 — Automação, Offline-First & Relatórios Periódicos
- **Fatia 4.1: Sincronização Delta com SwiftData / GRDB (Offline-First)**
- **Fatia 4.2: Relatórios Periódicos Agendados & Push APNs Nativo**
