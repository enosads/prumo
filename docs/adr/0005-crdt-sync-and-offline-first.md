# ADR-0005 — Sincronização Delta e Arquitetura Offline-First

**Status:** Accepted  
**Data:** 2026-08-18  
**Contexto:** Prumo — Gestão Financeira Familiar com IA Agêntica  
**Inspiração & Referência:** Calends (ADR-0002, ADR-006, Schema Sync v0.1)

---

## 1. Contexto

Um aplicativo financeiro pessoal é utilizado em cenários de conectividade instável (estacionamento de shopping, viagens, supermercado no subsolo). Lançar despesas ou consultar o limite de gastos não pode depender de conexão ativa com a internet.

---

## 2. Decisão

Adotamos a estratégia **Offline-First com Sincronização Delta**:

1. **Storage Local no iOS**:
   - O app mantém uma réplica local dos dados essenciais (contas, categorias, transações recentes, faturas abertas e orçamentos) no dispositivo do usuário.
2. **Protocolo de Sincronização Delta**:
   - Cada entidade possui `updated_at` com precisão de microssegundos e `version`.
   - Na reconexão, o cliente envia seu último `last_synced_at` e recebe apenas as mutações (`delta`) ocorridas desde então.
3. **Resolução de Conflitos**:
   - Operações financeiras de adição são comutativas (merge atômico).
   - Para mutações concorrentes na mesma entidade, aplica-se a estratégia determinística **Last-Write-Wins (LWW)** orientada por timestamp do servidor ou reconciliação explícita pelo usuário.

---

## 3. Consequências

- **Positivas**:
  - Abertura instantânea do app (0ms de latência percebida para renderizar o dashboard e extrato).
  - Lançamento de despesas sem bloqueio mesmo em modo avião, com sincronização em background quando a rede retornar.
