# ADR-0004 — Event Sourcing para Auditoria de IA e Integridade do Livro-Razão

**Status:** Accepted  
**Data:** 2026-08-18  
**Contexto:** Prumo — Gestão Financeira Familiar com IA Agêntica  
**Inspiração & Referência:** Calends (ADR-0003, Schema Copilot/Ledger v0.1)

---

## 1. Contexto

A automação por IA exige um nível de rastreabilidade e segurança incomparável com apps tradicionais. Quando a IA atua no modo autônomo (*act without asking*) ou no modo confirmação, o sistema precisa:
1. Garantir que **100% das ações e decisões da IA tenham auditoria imutável**.
2. Permitir o mecanismo de **Desfazer (Undo) por até 30 dias** de qualquer ação executada pela IA.
3. Preservar o histórico completo de mutações financeiras sem perda de integridade referencial.

---

## 2. Decisão

1. **Auditoria Imutável de IA (`Copilot` BC)**:
   - A tabela `ai_action_audits` é estritamente *append-only*.
   - Toda proposta, aprovação, execução, rejeição e reversão de `AIAction` gera um registro contendo: `action_id`, `user_id`, `family_id`, `model_used`, `diff_snapshot` (JSON) e `timestamp`.
2. **Mecanismo de Desfazer (*Undo*) Determinístico**:
   - Cada tipo de `AIAction` implementa uma função reversa determinística.
   - O `Undo` verifica pré-condições de integridade (ex: a transação a ser desfeita não pode ter sido liquidada em uma fatura fechada posterior).
3. **Livro-Razão Transacional (`Ledger` BC)**:
   - Toda edição em transações já reconciliadas preserva o histórico de versões através de snapshots.

---

## 3. Consequências

- **Positivas**:
  - Confiança total do usuário para delegar tarefas repetitivas ao agente de IA.
  - Conformidade nativa com LGPD/GDPR e rastreabilidade total de custos de inferência.
