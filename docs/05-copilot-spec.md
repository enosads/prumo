# Especificação Técnica — Copilot de IA & Agente Financeiro (Fase 2)

> **Documento de Engenharia & Contratos de Domínio**  
> **Status:** Aprovado para Implementação · **Fase:** 2

---

## 1. Visão Geral

O **Copilot do Prumo** é um agente financeiro conversacional e executor de tarefas com suporte a comandos em linguagem natural (texto e áudio) e processamento inteligente de documentos (faturas em PDF, comprovantes e fotos).

Ele opera com **dois níveis de fricção** controlados pelo usuário:
1. **Modo Confirmação (*Human-in-the-Loop* / Padrão)**: A IA elabora um plano de ação e apresenta o *diff* visual com botões de aprovação/rejeição.
2. **Modo Autônomo (*Act without asking*)**: Para tarefas repetitivas de baixo risco (ex: categorizar lote de transações com alta confiança, reconciliar parcelas de fatura), a IA executa diretamente e registra a trilha de auditoria.

---

## 2. Invariantes de Segurança & Auditoria

1. **A IA nunca age proativamente sem gatilho**: Toda ação tem origem em um comando explícito do usuário, importação de arquivo ou aceitação de sugestão.
2. **Tokenização de PII antes de enviar ao LLM**: CPF, CNPJ, dados de conta/cartão e dados sensíveis são mascarados em memória antes de trafegar para provedores externos (Anthropic / OpenAI / Gemini).
3. **Audit Trail Imutável (Append-Only)**: 100% das ações geradas pela IA são salvas na tabela `ai_action_audits`.
4. **Capacidade de Desfazer (Undo até 30 dias)**: Qualquer ação autônoma pode ser revertida preservando a integridade referencial do livro-razão (`ledger`).
5. **Hard Cap de Custos (Burn Cap)**: Limite mensal de consumo de tokens por família com degradação graciosa para processamento on-device ou erro explícito.

---

## 3. Máquina de Estados da `AIAction`

```
Modo Confirmação:   PROPOSED ──▶ APPROVED ──▶ EXECUTED
                        │
                        ├──▶ REJECTED
                        └──▶ EXPIRED (TTL 15 min)

Modo Autônomo:      PROPOSED ──▶ EXECUTED (se dentro do escopo autorizado)

Pós-Execução:       EXECUTED ──▶ UNDONE (via solicitação do usuário em até 30 dias)
```

---

## 4. Ferramentas do Agente (*Function Calling / Tools*)

| Nome da Tool | Tipo | Descrição |
| :--- | :---: | :--- |
| `get_consolidated_net_worth` | Leitura | Consulta saldo consolidado e por conta da família |
| `query_cash_flow` | Leitura | Filtra transações por período, categoria, membro e tipo |
| `get_budget_status` | Leitura | Analisa envelopes orçamentários e valor "Livre para Investir" |
| `get_card_projections` | Leitura | Consulta faturas abertas e projeção de 12 meses |
| `create_transaction` | Mutação | Lança despesa, receita ou transferência |
| `categorize_transactions_batch` | Mutação | Categoriza transações pendentes em lote |
| `anticipate_card_installments` | Mutação | Aplica antecipação de parcelas com cálculo de desconto |
| `adjust_budget_envelope` | Mutação | Altera teto orçamentário de uma categoria |

---

## 5. Próximos Passos de Implementação (Fase 2)

- **Fatia 2.1**: Adapters de LLM (Anthropic / OpenAI / Gemini), streaming SSE para chat iOS e tools de leitura.
- **Fatia 2.2**: Tools de mutação, cards interativos de aprovação no chat SwiftUI, audit trail e mecanismo de Undo.
