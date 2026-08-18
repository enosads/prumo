# Prumo — Roadmap de Desenvolvimento

> **Status**: Ativo · **Versão**: 1.0 · **Data**: 2026-08-18

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

## 🚀 Fase 1 — MVP Fluxo de Caixa, Cartões & Orçamento Familiar (Próxima)
- **Fatia 1.1: Gestão de Contas, Categorias & Lançamento Rápido**
  - Cadastro de categorias hierárquicas e transações (receitas/despesas/transferências).
  - Tela de Extrato com filtros por membro da família e busca instantânea.
- **Fatia 1.2: Cartões de Crédito, Faturas e Parcelamentos Mês a Mês**
  - Controle de limite, fechamento, vencimento e divisão de gastos por portador do cartão.
  - Tela de fatura com visão antecipada dos próximos 12 meses e antecipação com desconto.
- **Fatia 1.3: Orçamentos por Envelope e Metas de Economia**
  - Gestão de envelopes orçamentários por categoria com progresso visual no iOS.

---

## 🧠 Fase 2 — Agente de IA Nativo & Function Calling
- **Fatia 2.1: Orquestrador de IA & Chat Interativo com Streaming**
  - Adapters para Anthropic / OpenAI / Gemini e streaming WSS/SSE.
  - Ferramentas de consulta rápida (`get_consolidated_net_worth`, `query_transactions`).
- **Fatia 2.2: Execução de Ações Financeiras com Confirmação (*Human-in-the-Loop*)**
  - Ferramentas de mutação (`create_transaction`, `settle_invoice_installment`, `recalculate_budget_envelopes`).
  - Cards interativos de aprovação no chat iOS e trilha de auditoria (`ai_tool_executions`).

---

## 📈 Fase 3 — Módulo de Investimentos, Preço Médio & Tese Consultiva
- **Fatia 3.1: Carteiras B3, Global & Renda Fixa**
  - Registro de ordens de compra/venda com cálculo transacional de Preço Médio e Custo Total.
- **Fatia 3.2: Cotações EOD e Consultora de Investimentos**
  - Ingestão de cotações e proventos.
  - Ferramenta da IA que analisa desvios em relação à tese da família e orienta novos aportes.

---

## 🔄 Fase 4 — Automação, Offline-First & Relatórios Periódicos
- **Fatia 4.1: Sincronização Delta com SwiftData (Offline-First)**
- **Fatia 4.2: Relatórios Periódicos Agendados & Push APNs Nativo**
