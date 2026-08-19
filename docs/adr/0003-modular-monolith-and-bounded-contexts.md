# ADR-0003 — Modular Monolith em Go com Bounded Contexts e Preparação para Microsserviços

**Status:** Accepted  
**Data:** 2026-08-18  
**Contexto:** Prumo — Gestão Financeira Familiar com IA Agêntica  
**Inspiração & Referência:** Calends (ADR-0001, Bounded Contexts v1.0)

---

## 1. Contexto

O Prumo abrange múltiplos domínios funcionais complexos: controle transacional bancário, cálculo atuarial de faturas e parcelamentos, orçamentos familiares dinâmicos, agente de IA conversacional e ingestão de arquivos.
A decisão central reside em: construir uma arquitetura de microsserviços distribuídos desde o dia 1, um monólito tradicional ou um **Modular Monolith** com fronteiras rígidas de Bounded Contexts?

---

## 2. Opções Avaliadas

### Opção A: Microsserviços Distribuídos Imediatos
- Vários repositórios/binários independentes comunicando-se via rede (gRPC/REST/Kafka).
- **Desvantagens**: Overhead operacional imenso, transações distribuídas (sagas), latência de rede adicional em operações atômicas e infraestrutura cara no início.

### Opção B: Monólito Tradicional Não-Estruturado
- Código compartilhado sem fronteiras claras entre domínios.
- **Desvantagens**: Acoplamento spaghetti em poucos meses, dificultando testes unitários e impossibilitando extração futura para serviços especializados.

### Opção C: Modular Monolith em Go com Bounded Contexts (Recomendado)
- Um único binário executável no Go.
- Pastas internas isoladas por Bounded Context (`internal/identity`, `internal/ledger`, `internal/credit`, `internal/planning`, `internal/copilot`, `internal/import`, `internal/notification`, `internal/sync`, `internal/platform`).
- Comunicação cross-context exclusivamente via interfaces tipadas (`Ports`), contratos de domínio e eventos in-process (`EventBus`).

---

## 3. Decisão

Adotamos a **Opção C (Modular Monolith em Go)** com os seguintes pilares:

1. **Isolamento de Código**: Nenhum Bounded Context importa structs ou repositórios internos de outro.
2. **Transações Locais Seguras**: Mutações compostas (ex: pagamento de fatura no `Credit` debitando saldo no `Ledger`) usam portas com interfaces bem definidas.
3. **Prontidão para Microsserviços**: Quando um serviço (como o `Copilot` de IA ou o `Sync` em tempo real) precisar de escala independente, a extração para um microsserviço gRPC/Connect é imediata, bastando implementar o adapter remoto na porta existente.

---

## 4. Consequências

- **Positivas**:
  - Deploy simples e único container minimalista no Fly.io.
  - Testes unitários e de integração ultrarrápidos (`go test ./...` roda em segundos).
  - Custo de infraestrutura reduzido mantendo uma arquitetura de nível corporativo.
- **Disciplina Exigida**:
  - Respeitar estritamente as fronteiras dos pacotes internos sem atalhos de importação direta.
