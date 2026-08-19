# ADR-0002 — Taxonomia Hierárquica de Categorias & Alinhamento com Copilot de IA

**Status:** Accepted  
**Data:** 2026-08-18  
**Contexto:** Prumo — Gestão Financeira Familiar com IA Agêntica  
**Inspiração & Referência:** Calends (ADR-008, ADR-009, Schema Copilot v0.1)

---

## 1. Contexto

A categorização financeira é a âncora semântica de todo o sistema: alimenta o extrato, calcula os limites de envelope orçamentário e orienta as decisões dos agentes de IA (RAG e *Function Calling*).
A análise do projeto de referência **Calends** e dos requisitos no Linear (`team/FIN`) revelou que modelos puramente "livres" ou 100% customizados geram três problemas graves:
1. **Cold Start da IA**: Sem âncoras semânticas estáveis no onboarding, o LLM não tem referências seguras para classificar despesas vindas de PDF, OCR ou comandos de voz.
2. **Lixeira Semântica ("Outros")**: Permitir "Sem Categoria" ou "Outros" no seletor manual cria a rota de menor resistência cognitiva, degradando o valor analítico dos orçamentos em poucas semanas.
3. **Internacionalização e Slugs Imutáveis**: Nomes de categorias exibidos na interface (UI) precisam de tradução (`label_key` / `name`), mas os identificadores usados pela IA e pela lógica de backend precisam ser `slugs` universais estáveis em inglês (`food`, `housing`, `bills`, etc.).

---

## 2. Decisão

Adotamos a **Taxonomia Híbrida em 2 Níveis** com integração profunda com o módulo de IA:

### 2.1 Taxonomia Global (13 Roots Semânticas + 1 Categoria de Sistema)

| # | Slug | Nome Padrão (pt-BR) | Escopo & Exemplos |
|---|---|---|---|
| 1 | `housing` | Moradia | Aluguel, condomínio, IPTU, reformas, manutenção |
| 2 | `bills` | Contas & Assinaturas | Luz, água, gás, internet, streaming, planos recorrentes |
| 3 | `food` | Alimentação & Mercado | Supermercado, feira, restaurantes, delivery, cafés |
| 4 | `transport` | Transporte | Combustível, transporte público, corrida por app, estacionamento |
| 5 | `health` | Saúde & Farmácia | Plano de saúde, consultas, farmácia, exames, terapia |
| 6 | `education` | Educação | Mensalidade, cursos, livros técnicos, certificações |
| 7 | `leisure` | Lazer & Viagens | Cinema, shows, viagens, passeios, eventos, jogos |
| 8 | `personal_care` | Cuidados Pessoais | Barbeiro, salão, academia, cosméticos, estética |
| 9 | `shopping` | Compras & Roupas | Vestuário, eletrônicos, compras para o lar |
| 10 | `giving` | Doações & Presentes | Doações filantrópicas (dedução fiscal), presentes para terceiros |
| 11 | `financial` | Taxas & Impostos | Tarifas bancárias, juros, DARF, impostos |
| 12 | `income` | Receitas | Salário, freelance, rendimentos, reembolsos |
| 13 | `transfer` | Transferências | Movimentações entre contas do mesmo núcleo familiar |
| — | `uncategorized` | Não Categorizado | **Categoria de Sistema** (ver abaixo) |

### 2.2 Regras da Categoria de Sistema: `uncategorized`
- **Invisível no seletor manual** (`system_only = true`): O usuário não pode escolher "Não Categorizado" ao lançar despesas manualmente.
- **Inbox Transitório**: Usado exclusivamente como destino temporário quando a IA ou OCR tiverem baixa confiança na classificação de faturas/comprovantes importados.
- **Badge de Dívida Cognitiva**: O app destaca transações em `uncategorized` com um badge para revisão rápida e confirmação com 1 toque.

### 2.3 Categorias Customizadas e Subcategorias
- O usuário e a família podem criar novas categorias e subcategorias sob qualquer uma das raízes globais ou de forma independente (profundidade máxima de 2 níveis: Grupo ➔ Subcategoria).

### 2.4 Alinhamento com o Copilot de IA (Fase 2)
1. **Modo Confirmação vs. Modo Autônomo**:
   - **Confirmação (Padrão)**: A IA sugere ações (ex: categorizar lote, criar parcelas) e apresenta o *diff* visual para aprovação do usuário.
   - **Autônomo**: A IA executa categorizações e deduplicações diretamente para escopos permitidos pelo usuário, registrando auditoria imutável (`audit_entries`) com opção de **Desfazer (Undo) por até 30 dias**.
2. **Tokenização de PII**:
   - Nenhum dado pessoal identificável (CPF, número de cartão, nomes completos de terceiros) é enviado ao LLM sem mascaramento/tokenização prévia.
3. **Burn Cap & Quota de IA**:
   - Hard cap de inferência por usuário/família para controle de custos.

---

## 3. Consequências

- **Positivas**:
  - A IA agêntica da Fase 2 terá âncoras semânticas determinísticas desde o primeiro dia.
  - Orçamentos por envelope familiares tornam-se imediatamente funcionais sem exigir configuração manual exaustiva no primeiro uso.
  - Preparação para relatórios fiscais (separação de `giving` e `bills` de `housing`).
