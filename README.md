# Prumo 🧭

**Prumo** é um ecossistema multiplataforma de gestão financeira pessoal e familiar (projetado especialmente para o contexto de casais e famílias), integrado a um assistente inteligente nativo com capacidades de execução por **Function Calling / Tool Use** com confirmação em duas etapas (*Human-in-the-Loop*).

---

## 🎯 Visão do Produto

- **Núcleos Familiares & Espaços Compartilhados**: Gestão transparente do patrimônio do casal com segregação de contas compartilhadas vs. privadas e controle de papéis (`owner`, `admin`, `member`, `viewer`).
- **Fluxo de Caixa & Orçamentos por Envelope**: Lançamento rápido de receitas, despesas, transferências, categorias hierárquicas personalizáveis e metas mensais com saldo livre para investir.
- **Cartões de Crédito, Faturas e Parcelamentos**: Controle detalhado de compras parceladas mês a mês (próximos 12 meses), divisão de gastos por portador do cartão e simulação de antecipação com desconto.
- **Investimentos Nacionais (B3/RF/Fundos) e Internacionais (EUA/REITs/Crypto)**: Cálculo automático de Preço Médio e Custo Total, marcação a mercado, proventos (dividendos/JCP) e rebalanceamento orientado pela tese declarada pela família.
- **Agente de IA Agêntica com Execução Segura**: Consulta contextualizada e execução de mutações financeiras com `approval_token` e confirmação visual na interface do app.

---

## 🛠️ Stack Tecnológica & Arquitetura

- **Backend**: Go (Go 1.24+), Clean Architecture / Hexagonal Architecture, roteamento REST fortemente tipado com **Chi** e **Huma v2** (OpenAPI 3.0 nativo), concorrência idiomática e WebSocket.
- **Banco de Dados**: **PostgreSQL 18** com migrações versionadas (`golang-migrate`) e consultas SQL puras compiladas para Go tipado com **sqlc** e quality gate de tipagem via `sqlcprepare`.
- **Cache & Filas**: **Redis 7** para cache de cotações, rate limiting e background workers.
- **Frontend / iOS**: **Swift 6 / SwiftUI** nativo (iOS 17+), gerado via **XcodeGen** (`project.yml`), arquitetura com **Observation framework** (`@Observable`), Swift Concurrency (`async/await`, `Actors`), componentes monetários fluidos e design tokens no `Brand.swift`.
- **CI/CD**: **GitHub Actions** automatizado para backend (PostgreSQL 18, Redis, `sqlcprepare`, testes unitários com `-race`, `smoke.sh`) e iOS (Xcode 16 + XcodeGen build no simulador).

---

## 📚 Documentação

A documentação viva do projeto está centralizada no diretório [`docs/`](docs/):

| Documento | Descrição |
|---|---|
| [`docs/01-requisitos.md`](docs/01-requisitos.md) | Especificação detalhada de Requisitos Funcionais (RF) e Não-Funcionais (RNF). |
| [`docs/02-arquitetura.md`](docs/02-arquitetura.md) | Blueprint arquitetural, C4 Context/Container e Modelo Entidade-Relacionamento (ERD). |
| [`docs/03-roadmap.md`](docs/03-roadmap.md) | Fases de entrega: Fundação ✅ → MVP Fluxo de Caixa → IA Nativa → Investimentos → Offline/Automação. |
| [`docs/04-fatia-atual.md`](docs/04-fatia-atual.md) | Documento de trabalho com o escopo da fatia em andamento e convenções vigentes. |
| [`CLAUDE.md`](CLAUDE.md) | Guia condensado de engenharia e comandos rápidos para agentes e desenvolvedores. |

---

## 📂 Estrutura do Repositório (Monorepo)

```
prumo/
├── .github/workflows/           # CI/CD GitHub Actions (backend.yml e ios.yml)
├── backend/
│   ├── cmd/
│   │   ├── server/              # Entrypoint da API HTTP/WSS (porta 8085)
│   │   └── sqlcprepare/         # Validador estrito de queries contra o PostgreSQL 18
│   ├── internal/
│   │   ├── api/                 # Handlers Huma v2, rotas OpenAPI 3.0 e middlewares
│   │   ├── auth/ & authz/       # Emissão de JWT multi-tenant, bcrypt e matriz RBAC
│   │   ├── config/              # Configurações de ambiente tipadas
│   │   ├── db/                  # Queries SQL e código tipado gerado pelo sqlc
│   │   └── domain/              # Entidades puras e cálculos financeiros (Money/Cents)
│   ├── migrations/              # Migrações SQL numeradas sequencialmente (.up.sql / .down.sql)
│   ├── openapi.json             # Especificação OpenAPI 3.0 gerada
│   └── sqlc.yaml                # Configuração e type overrides do sqlc
├── ios/
│   ├── App/
│   │   ├── Sources/
│   │   │   ├── Core/            # APIClient, AuthSession, Brand, Models, CampoMonetario
│   │   │   └── Features/        # Telas de Auth, Dashboard, CashFlow, Cards, Budgets, Investments
│   │   └── Resources/           # Asset Catalog (Brand colors, Icons)
│   └── project.yml              # Especificação declarativa do XcodeGen
├── scripts/
│   └── smoke.sh                 # Smoke test E2E da API com 10 asserções automatizadas
├── docs/                        # Documentação viva do ecossistema
└── Makefile                     # Automação de tarefas locais e CI
```

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- [Go 1.24+](https://go.dev/)
- [Docker](https://www.docker.com/) e Docker Compose
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Ferramentas Go: `sqlc` e `migrate` (`go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest` e `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest`)

### 1. Iniciar Banco de Dados e Cache
```bash
# Sobe o PostgreSQL 18 (porta 5434) e Redis 7 (porta 6380)
make compose-up

# Aplica as migrations do banco de dados
make migrate-up
```

### 2. Rodar o Backend Go
```bash
# Executa o quality gate de validação de queries com o Postgres
make sqlc-prepare

# Inicia o servidor da API (porta 8085)
make be-run
```
> Documentação interativa Swagger/OpenAPI disponível em: `http://localhost:8085/docs`

### 3. Executar o Smoke Test E2E
Com o servidor rodando, execute em outro terminal:
```bash
make smoke
```

### 4. Gerar e Compilar o App iOS
```bash
# Gera o Prumo.xcodeproj sem conflitos de git
make ios-gen

# Compila para o simulador iOS
make ios-build
```

---

## 🧪 Comandos Úteis do Makefile

| Comando | Descrição |
|---|---|
| `make compose-up` | Inicia os containers do PostgreSQL 18 e Redis |
| `make migrate-up` | Aplica todas as migrations pendentes |
| `make sqlc-gen` | Regenera o código Go a partir das queries SQL |
| `make sqlc-prepare` | Valida todas as 55 consultas diretamente contra o PostgreSQL |
| `make be-test` | Executa os testes unitários Go com detector de race conditions (`-race`) |
| `make be-run` | Executa a API localmente na porta `8085` |
| `make smoke` | Executa o fluxo de testes E2E com `curl` e asserções estritas |
| `make api-spec` | Exporta a especificação OpenAPI 3.0 atualizada para `backend/openapi.json` |
| `make ios-gen` | Gera o projeto Xcode via XcodeGen |
| `make ios-build` | Compila o aplicativo para o simulador iOS |

---

## 📄 Licença
Propriedade de [Enos Andrade](https://github.com/enosads). Todos os direitos reservados.
