# Fatia Atual — Fase 1: MVP de Fluxo de Caixa, Cartões & Orçamento

> **Status**: Concluída · **Fase**: 1 (Fluxo de Caixa & Orçamento) · **Data de Conclusão**: 2026-08-18

## Objetivo da Fatia
Construir o motor financeiro e a experiência do usuário do **Prumo**:
1. **Fatia 1.1: Categorias & Lançamento de Transações (Extrato Familiar)**
   - CRUD completo de categorias (`/v1/categories`) com auto-seed de categorias padrão familiares.
   - Lançamento de Receitas, Despesas e Transferências atômicas entre contas (`/v1/transactions`).
   - Extrato no app iOS (`CashFlowView.swift`) agrupado por dia, com busca, filtros por tipo e membro responsável.
   - Sheet de Lançamento Rápido (`NewTransactionSheet.swift`) com `CampoMonetario.swift`, seletor visual de categoria e parcelas.
2. **Fatia 1.2: Cartões de Crédito, Faturas e Parcelamentos Mês a Mês**
   - Endpoints de cartões (`/v1/cards`), faturas mensais e pagamento com débito em conta corrente (`/v1/cards/{id}/invoices/{id}/pay`).
   - Motor de compras parceladas com geração automática de parcelas distribuídas nas faturas subsequentes.
   - Projeção de faturas dos próximos 12 meses (`/v1/cards/{id}/installments`) com divisão de gastos por membro do casal.
   - Simulação e aplicação de antecipação de parcelas com cálculo a valor presente (`/v1/cards/{id}/installments/anticipate`).
   - Telas iOS: Carrossel moderno de cartões (`CardsView.swift`), detalhes e pagamento de fatura (`CardDetailView.swift`) e sheet de antecipação (`AnticipateInstallmentsSheet.swift`).
3. **Fatia 1.3: Orçamentos por Envelope e Metas de Economia**
   - Envelopes mensais por categoria (`/v1/budgets` e `/v1/budgets/{id}/items`) com cálculo de realizado vs. orçado.
   - Cálculo automático do valor "Livre para Investir" no mês.
   - Tela iOS de envelopes (`BudgetsView.swift`) com seletor de mês e barras de progresso com transição de cor (Verde <75%, Âmbar 75-100%, Vermelho >100%) e sheet de configuração (`SetBudgetItemSheet.swift`).

## Checklist de Entrega
- [x] Schema DDL, queries sqlc (`categories.sql`, `transactions.sql`, `cards.sql`, `budgets.sql`) e quality gate `sqlcprepare` (75 queries aprovadas)
- [x] Endpoints Go Huma v2 implementados e integrados no router
- [x] Testes unitários de domínio financeiro (`calculations_test.go`)
- [x] Telas e componentes SwiftUI nativos (iOS 17+) compilados com sucesso via XcodeGen
- [x] Suíte de 26 Smoke Tests E2E (`scripts/smoke.sh`) passando com 100% de sucesso
- [x] Contrato OpenAPI atualizado (`backend/openapi.json`)

