# Fatia Atual — 0.1 & 0.2: Fundação, Multi-Tenancy & Scaffolding Inicial

> **Status**: Em Execução · **Fase**: 0 (Fundação) · **Data de Início**: 2026-08-18

## Objetivo da Fatia
Construir o alicerce do ecossistema **Prumo**:
1. **Infraestrutura**: Configurar PostgreSQL 18 e Redis no `docker-compose.yml` (porta 5434).
2. **Schema & Banco**: Criar o schema relacional inicial (`0001_initial_schema.up.sql`), queries SQL e geração de código tipado via `sqlc` com quality gate no `sqlcprepare`.
3. **Backend Go**: Implementar o servidor HTTP com Chi e Huma v2 OpenAPI 3.0, middlewares de recuperação/logging, emissão e validação de JWT multi-tenant com claims de família e RBAC (`owner`, `admin`, `member`, `viewer`), handlers de registro, login, gerenciamento de membros familiares e contas financeiras.
4. **App iOS**: Configuração do projeto via XcodeGen (`project.yml`), design tokens em `Brand.swift`, cliente de API assíncrono `APIClient.swift`, gerenciador de sessão `AuthSession.swift` com keychain seguro e telas base de Autenticação e Dashboard.
5. **Quality Gate**: Automação do `scripts/smoke.sh` cobrindo registro de usuário, criação de família, convite de parceiro(a), troca de papéis, listagem de contas e asserção de erros de autenticação (401/403/422).

## Convenções da Fatia
- Nomes de tabelas e colunas em inglês; documentação e comentários em português.
- Dinheiro sempre em inteiros (`amount_cents BIGINT`).
- Multi-tenancy validado no nível de middleware com injeção de contexto (`FamilyID`, `UserID`, `Role`).

## Checklist de Entrega
- [x] Blueprint arquitetural aprovado
- [ ] Docker compose com Postgres 18 e Redis ativo
- [ ] Schema inicial DDL e migrations aplicadas
- [ ] Configuração do sqlc e queries compiladas
- [ ] Endpoints Huma v2 implementados (`/v1/auth/register`, `/v1/auth/login`, `/v1/families`, `/v1/accounts`)
- [ ] Setup do XcodeGen e compilação do target iOS
- [ ] Execução com sucesso do `scripts/smoke.sh`
