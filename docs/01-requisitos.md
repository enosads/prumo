# Prumo — Especificação de Requisitos

> **Status**: Ativo · **Versão**: 1.0 · **Data**: 2026-08-18

---

## 1. Visão Geral do Produto
O **Prumo** é um ecossistema multiplataforma de gestão financeira familiar com assistente nativo de Inteligência Artificial agêntica (Function Calling). O sistema permite o gerenciamento unificado do patrimônio de casais e famílias, com segregação de contas compartilhadas vs. individuais, acompanhamento de cartões de crédito e faturas, controle de orçamentos por envelope, consolidação de investimentos (B3, Global, Renda Fixa) e assessoria consultiva automatizada.

---

## 2. Requisitos Funcionais (RF)

### 2.1 Identidade, Família & Multi-Tenancy
- **RF-01**: O sistema deve permitir o cadastro de usuários por e-mail/senha e autenticação social (Apple ID / Google).
- **RF-02**: Ao se cadastrar, o usuário cria automaticamente um Núcleo Familiar padrão (`family_id`), assumindo o papel de `owner`.
- **RF-03**: O `owner` ou `admin` pode convidar outros membros familiares via e-mail com link/código seguro.
- **RF-04**: O sistema deve suportar os seguintes papéis:
  - `owner`: Acesso total e gerência de faturamento/exclusão.
  - `admin`: Gerência de membros, contas e finanças.
  - `member`: Leitura e escrita de transações e contas compartilhadas.
  - `viewer`: Apenas leitura de relatórios e saldos compartilhados.
- **RF-05**: Um usuário pode pertencer a múltiplos núcleos familiares (ex: casal e família estendida/negócio pessoal).

### 2.2 Contas & Cartões de Crédito
- **RF-06**: Cadastro de contas com tipo (`checking`, `savings`, `investment`, `cash`, `credit_card`) e moeda (`BRL`, `USD`).
- **RF-07**: Controle de visibilidade da conta (`shared` vs `private`). Contas privadas só são visíveis pelo titular.
- **RF-08**: Gestão de cartões de crédito com definição de limite, dia de fechamento e dia de vencimento.
- **RF-09**: Agrupamento e projeção de compras parceladas mês a mês com controle de parcelas restantes e antecipação com desconto.

### 2.3 Fluxo de Caixa & Orçamento Familiar
- **RF-10**: Lançamento de despesas, receitas e transferências entre contas.
- **RF-11**: Categorização hierárquica personalizável por família (com ícone e cor).
- **RF-12**: Orçamento mensal por envelopes com metas de teto de gastos e cálculo de saldo livre para investir.

### 2.4 Investimentos & Tese do Usuário
- **RF-13**: Suporte a ativos da B3 (Ações, FIIs, BDRs, ETFs), Renda Fixa, Fundos, Criptoativos e Ativos Internacionais (US Stocks, REITs, ETFs).
- **RF-14**: Cálculo automatizado de Preço Médio, Custo Total e Rentabilidade por ativo e classe.
- **RF-15**: Cadastro da Tese de Investimentos da Família (alocação percentual alvo por classe e tolerância a risco).
- **RF-16**: Motor de rebalanceamento que orienta onde alocar novos aportes para atingir a meta da tese.

### 2.5 Agente de IA com Function Calling
- **RF-17**: Chat conversacional com streaming de respostas (WebSocket/SSE).
- **RF-18**: Execução de ferramentas seguras de consulta (patrimônio líquido, projeções, análise de tese).
- **RF-19**: Execução de ferramentas de mutação financeiras mediante confirmação explícita (*Human-in-the-Loop* com token de aprovação).
- **RF-20**: Trilha de auditoria completa de cada execução de ferramenta pela IA.

---

## 3. Requisitos Não Funcionais (RNF)

- **RNF-01 (Precisão Financeira)**: Todos os cálculos monetários devem utilizar representação inteira em centavos (`bigint`) ou `numeric(18, 8)` para frações de ativos. Ponto flutuante (`float`) é proibido para valores monetários.
- **RNF-02 (Segurança & RBAC)**: Toda requisição à API é autenticada por JWT com validação estrita de escopo multi-tenant (`family_id`).
- **RNF-03 (Performance)**: Endpoints de consulta devem responder em menos de 100ms no percentil 95 (P95).
- **RNF-04 (Offline-First)**: O app iOS deve permitir o lançamento e consulta básica de dados sem conexão via persistência local no SwiftData.
- **RNF-05 (Automação de Qualidade)**: Nenhuma alteração sobe para produção sem passar por `make sqlc-prepare`, `make be-test -race`, `make be-lint` e `scripts/smoke.sh`.
