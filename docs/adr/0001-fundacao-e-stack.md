# ADR-0001 — Fundação Arquitetural, Stack Tecnológica & Multi-Tenancy

**Status:** Accepted  
**Data:** 2026-08-18  
**Contexto:** Prumo — Gestão Financeira Familiar com IA Agêntica

---

## 1. Contexto e Motivação

O **Prumo** é um ecossistema multiplataforma de gestão financeira pessoal e familiar com foco em transparência, divisão de despesas conjugais, planejamento de fluxo de caixa e assistência com IA agêntica.
Era necessário definir a arquitetura base do backend, persistência, modelo de multi-tenancy e stack mobile nativa para suportar evolução contínua sem necessidade de reescritas prematuras.

---

## 2. Decisão

1. **Backend**:
   - **Linguagem**: Go 1.24+ (alta performance, baixo consumo de memória e concorrência nativa com goroutines).
   - **Framework HTTP**: Chi Router + Huma v2 OpenAPI 3.0 (geração automática de contratos OpenAPI e validação declarativa de payloads).
   - **Autenticação**: Tokens JWT assinados com `HMAC-SHA256` e refresh tokens com rotação e revogação em banco.
2. **Banco de Dados & Persistência**:
   - **PostgreSQL 18**: Banco de dados relacional com forte consistência transacional ACID para valores monetários inteiros em centavos (`bigint`).
   - **SQL Type-Safe**: `sqlc` + `sqlcprepare` para queries SQL nativas tipadas e validadas em tempo de build.
   - **Redis**: Cache de sessões e rate limiting.
3. **Multi-Tenancy Familiar**:
   - Isolamento lógico por núcleo familiar (`family_id` UUID obrigatório em todas as entidades financeiras: contas, categorias, transações, cartões e orçamentos).
   - RBAC por membro da família (`owner`, `admin`, `member`, `viewer`).
4. **Frontend Mobile**:
   - **iOS Nativo (iOS 17+)**: SwiftUI com Swift 6 e `@Observable`, utilizando XcodeGen (`project.yml`) para reprodutibilidade de build.
   - Design System com tokens centrais em `Brand.swift` e componentes monetários atômicos (`CampoMonetario.swift`).

---

## 3. Consequências

- **Positivas**:
  - Segurança transacional absoluta com cálculos monetários determinísticos em centavos.
  - Baixa latência e inicialização rápida do backend Go em containers minimalistas Alpine no Fly.io.
  - App iOS 100% nativo e responsivo.
- **Negativas / Desafios**:
  - Exige manter schemas DDL sincronizados via migrations sequenciais no PostgreSQL.
