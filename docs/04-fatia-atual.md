# Fatia Atual — Fase 2: Agente de IA Nativo & Taxonomia Enriquecida

> **Status**: Em Planejamento / Kick-off · **Fase**: 2 · **Data de Início**: 2026-08-18  
> **Referências**: [ADR-0001](file:///Users/enosads/www/personal/prumo/docs/adr/0001-fundacao-e-stack.md), [ADR-0002](file:///Users/enosads/www/personal/prumo/docs/adr/0002-taxonomy-and-copilot-alignment.md), [Especificação do Copilot](file:///Users/enosads/www/personal/prumo/docs/05-copilot-spec.md)

---

## Objetivo da Fatia 2.1
1. **Taxonomia das 13 Roots Globais**:
   - Evoluir a migration de categorias para suportar a matriz de 13 raízes semânticas com `slug` imutável em inglês e `label` pt-BR.
   - Implementar a flag `system_only` para a categoria `uncategorized`.
2. **Orquestrador de IA & Endpoints de Chat**:
   - Implementar o package `backend/internal/ai` com adapters para Anthropic, OpenAI e Gemini.
   - Endpoint de streaming SSE `/v1/ai/chat` com autenticação JWT e isolamento de família.
   - Tools de consulta (*read-only*) para saldo consolidado, extrato, faturas e orçamentos.
3. **Interface iOS de Chat Financeiro**:
   - Nova aba ou botão rápido de Chat com IA (`ChatView.swift`) consumindo streaming SSE.
