# Prumo — Guia do Desenvolvedor & Agente

Monorepo do ecossistema **Prumo**: Gestão Financeira Familiar com IA Agêntica (Tool Calling).
- **Backend**: Go 1.24+ (Chi + Huma v2 OpenAPI 3.0, PostgreSQL 18 + sqlc, Redis, APNs nativo).
- **Frontend / iOS**: SwiftUI nativo (Swift 6 / 5.10, XcodeGen, SwiftData, Observation framework).
- **IA**: Orquestrador com Function Calling / Tool Calling seguro em duas etapas (Human-in-the-Loop).

## Regras de Leitura e Trabalho
1. **Trabalho em Fatias Verticais**: Sempre entregar ponta a ponta (Backend + iOS + DB + Testes), documentando em `docs/04-fatia-atual.md`.
2. **Convenções de Commit**: Commits em português (`feat:`, `fix:`, `test:`, `docs:`, `chore:`). Sem `\n` nas mensagens.
3. **Database & sqlc**: Nunca edite `backend/internal/db/sqlc/` manualmente. Altere `migrations/` e `queries/`, e execute `make sqlc-gen` e `make sqlc-prepare`.
4. **Precisão Numérica**: Dinheiro sempre em inteiros (`amount_cents BIGINT`), ativos fracionários em `NUMERIC(18, 8)`.

## Mapa do Código
- `backend/cmd/server/`: Entrypoint da API HTTP/WSS.
- `backend/cmd/sqlcprepare/`: Quality gate de validação de queries com Postgres.
- `backend/internal/api/`: Handlers HTTP Huma v2 e rotas da API.
- `backend/internal/ai/`: Motor de IA, adapters de LLM e catálogo de Tools/Functions.
- `backend/internal/domain/`: Entidades de domínio, cálculos financeiros e teses de investimento.
- `backend/internal/db/`: Queries SQL e código gerado por sqlc.
- `backend/migrations/`: Migrações SQL numeradas sequencialmente (`0001_...`).
- `ios/App/Sources/Core/`: `APIClient.swift`, `AuthSession.swift`, `Brand.swift`, `Models.swift`.
- `ios/App/Sources/Features/`: Módulos funcionais (`Auth/`, `Dashboard/`, `CashFlow/`, `Cards/`, `Budgets/`, `Investments/`, `AIChat/`).
- `scripts/smoke.sh`: Smoke test E2E da API.

## Comandos Frequentes
- Iniciar containers: `make compose-up`
- Migrations: `make migrate-up`
- Gerar sqlc: `make sqlc-gen` && `make sqlc-prepare`
- Rodar API local: `make be-run`
- Rodar testes Go: `make be-test`
- Executar Smoke Test: `make smoke`
- Gerar projeto iOS: `make ios-gen`
- Compilar iOS: `make ios-build`
