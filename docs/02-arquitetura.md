# Prumo — Arquitetura de Software

> **Status**: Ativo · **Versão**: 1.0 · **Data**: 2026-08-18

---

## 1. Visão Geral
O **Prumo** adota arquitetura de monólito modular em **Go (Go 1.24+)** servindo API REST OpenAPI 3.0 via **Chi + Huma v2** e WebSocket para streaming de IA em tempo real. A camada de persistência utiliza **PostgreSQL 18** com acesso fortemente tipado gerado por **sqlc** e migrações versionadas com **golang-migrate**. O aplicativo cliente é desenvolvido em **SwiftUI (Swift 6)** nativo para iOS, com geração de projeto desacoplada via **XcodeGen**.

```mermaid
flowchart LR
    subgraph Clientes
        IOS[App iOS - SwiftUI / SwiftData]
    end

    subgraph "Backend Prumo (Go)"
        API[API HTTP REST OpenAPI 3.0 & WSS]
        Engine[Motor de IA & Tool Calling]
        Worker[Workers de Background & Scheduler]
    end

    subgraph Armazenamento
        PG[(PostgreSQL 18)]
        REDIS[(Redis / Valkey)]
        R2[(Cloudflare R2 - Extratos e Anexos)]
    end

    subgraph Externos
        APNS[Apple APNs Push HTTP/2]
        LLM[Anthropic Claude / OpenAI / Gemini]
        Market[Market Data APIs]
    end

    IOS -->|HTTPS / WSS| API
    API --> PG
    API --> REDIS
    API --> Engine
    Engine --> LLM
    Worker --> Market
    Worker --> APNS
```

---

## 2. Decisões Arquiteturais Fundamentais

| Decisão | Escolha | Motivo |
|---|---|---|
| **Arquitetura do Backend** | Go (Monólito Modular) | Binário único, performance superior, concorrência idiomática e baixo consumo de memória. |
| **API & Contratos** | Chi + Huma v2 (OpenAPI 3.0) | Validação automática com JSON Schemas, documentação viva nativa e tipagem estrita de payloads. |
| **Persistência Relacional** | PostgreSQL 18 + `sqlc` + `golang-migrate` | SQL nativo compilado sem overhead de ORMs; type-safety garantido em tempo de build. |
| **Quality Gate de Banco** | `sqlcprepare` | Executa `PREPARE` de todas as queries contra o Postgres para evitar bugs de tipos de parâmetros (ex: 42P08). |
| **App Mobile** | SwiftUI nativo (iOS 17+) com XcodeGen | Interface fluida, animações no padrão iOS HIG, sem conflitos de merge no `.xcodeproj`. |
| **Segurança da IA** | Function Calling com Aprovação em 2 Etapas | Ações financeiras de escrita requerem `approval_token` e confirmação explícita do usuário na UI. |

---

## 3. Diagrama Entidade-Relacionamento do Banco de Dados

```mermaid
erDiagram
    families ||--o{ family_members : contains
    families ||--o{ accounts : owns
    families ||--o{ categories : customizes
    families ||--o{ budgets : plans
    families ||--o{ investment_theses : establishes
    families ||--o{ ai_conversations : conducts

    users ||--o{ family_members : participates
    users ||--o{ auth_identities : authenticates
    users ||--o{ user_devices : registers
    users ||--o{ transactions : authors

    accounts ||--o{ credit_cards : issues
    accounts ||--o{ transactions : logs
    accounts ||--o{ investment_positions : holds
    accounts ||--o{ investment_orders : executes

    credit_cards ||--o{ credit_card_invoices : generates
    categories ||--o{ transactions : classifies
    budgets ||--o{ budget_items : contains

    investment_assets ||--o{ investment_positions : tracks
    investment_assets ||--o{ investment_orders : buys_sells
    ai_conversations ||--o{ ai_messages : contains
    ai_messages ||--o{ ai_tool_executions : records
```
