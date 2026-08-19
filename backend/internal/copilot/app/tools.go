package app

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"

	copilotDomain "github.com/enosads/prumo/backend/internal/copilot/domain"
	creditDomain "github.com/enosads/prumo/backend/internal/credit/domain"
	ledgerDomain "github.com/enosads/prumo/backend/internal/ledger/domain"
	planningDomain "github.com/enosads/prumo/backend/internal/planning/domain"
)

type ToolRegistry struct {
	ledgerPort   ledgerDomain.LedgerPort
	creditPort   creditDomain.CreditPort
	planningPort planningDomain.PlanningPort
}

func NewToolRegistry(ledger ledgerDomain.LedgerPort, credit creditDomain.CreditPort, planning planningDomain.PlanningPort) *ToolRegistry {
	return &ToolRegistry{
		ledgerPort:   ledger,
		creditPort:   credit,
		planningPort: planning,
	}
}

func (r *ToolRegistry) GetToolDefinitions() []copilotDomain.ToolDefinition {
	return []copilotDomain.ToolDefinition{
		{
			Name:        "get_consolidated_net_worth",
			Description: "Consulta o saldo consolidado e o patrimônio líquido total por conta do núcleo familiar.",
			Parameters: copilotDomain.ToolParameterSchema{
				Type:       "object",
				Properties: map[string]interface{}{},
			},
		},
		{
			Name:        "query_cash_flow",
			Description: "Filtra e consulta o extrato e fluxo de caixa de transações da família por período, categoria, tipo (income/expense/transfer) ou usuário.",
			Parameters: copilotDomain.ToolParameterSchema{
				Type: "object",
				Properties: map[string]interface{}{
					"category_slug": map[string]interface{}{
						"type":        "string",
						"description": "Slug da categoria canônica (ex: food, housing, bills, transport, health, leisure, shopping, education, income)",
					},
					"kind": map[string]interface{}{
						"type":        "string",
						"enum":        []string{"income", "expense", "transfer"},
						"description": "Tipo da transação",
					},
					"from_date": map[string]interface{}{
						"type":        "string",
						"description": "Data inicial no formato ISO 8601 (YYYY-MM-DD)",
					},
					"to_date": map[string]interface{}{
						"type":        "string",
						"description": "Data final no formato ISO 8601 (YYYY-MM-DD)",
					},
					"limit": map[string]interface{}{
						"type":        "integer",
						"description": "Quantidade máxima de registros (padrão 20)",
					},
				},
			},
		},
		{
			Name:        "get_budget_status",
			Description: "Analisa o status dos envelopes de orçamento da família no mês, calculando desvios e o valor 'Livre para Investir'.",
			Parameters: copilotDomain.ToolParameterSchema{
				Type: "object",
				Properties: map[string]interface{}{
					"period_year": map[string]interface{}{
						"type":        "integer",
						"description": "Ano do orçamento (ex: 2026)",
					},
					"period_month": map[string]interface{}{
						"type":        "integer",
						"description": "Mês do orçamento (1 a 12)",
					},
				},
			},
		},
		{
			Name:        "get_card_projections",
			Description: "Consulta as faturas abertas, limites disponíveis e parcelas futuras projetadas de cartões de crédito da família para os próximos meses.",
			Parameters: copilotDomain.ToolParameterSchema{
				Type: "object",
				Properties: map[string]interface{}{
					"months_ahead": map[string]interface{}{
						"type":        "integer",
						"description": "Número de meses à frente para projeção (padrão 12)",
					},
				},
			},
		},
	}
}

func (r *ToolRegistry) ExecuteTool(ctx context.Context, familyID, userID uuid.UUID, toolName string, args json.RawMessage) (json.RawMessage, error) {
	switch toolName {
	case "get_consolidated_net_worth":
		res, err := r.ledgerPort.GetConsolidatedNetWorth(ctx, familyID)
		if err != nil {
			return nil, err
		}
		return json.Marshal(res)

	case "query_cash_flow":
		var params struct {
			CategorySlug *string `json:"category_slug"`
			Kind         *string `json:"kind"`
			FromDate     *string `json:"from_date"`
			ToDate       *string `json:"to_date"`
			Limit        *int    `json:"limit"`
		}
		_ = json.Unmarshal(args, &params)

		filter := ledgerDomain.CashFlowFilter{
			FamilyID:     familyID,
			CategorySlug: params.CategorySlug,
			Kind:         params.Kind,
			Limit:        20,
		}
		if params.Limit != nil && *params.Limit > 0 {
			filter.Limit = *params.Limit
		}
		if params.FromDate != nil && *params.FromDate != "" {
			if t, err := time.Parse("2006-01-02", *params.FromDate); err == nil {
				filter.FromDate = &t
			}
		}
		if params.ToDate != nil && *params.ToDate != "" {
			if t, err := time.Parse("2006-01-02", *params.ToDate); err == nil {
				filter.ToDate = &t
			}
		}

		res, err := r.ledgerPort.QueryCashFlow(ctx, filter)
		if err != nil {
			return nil, err
		}
		return json.Marshal(res)

	case "get_budget_status":
		var params struct {
			PeriodYear  *int16 `json:"period_year"`
			PeriodMonth *int16 `json:"period_month"`
		}
		_ = json.Unmarshal(args, &params)

		var y, m int16
		if params.PeriodYear != nil {
			y = *params.PeriodYear
		}
		if params.PeriodMonth != nil {
			m = *params.PeriodMonth
		}

		res, err := r.planningPort.GetBudgetStatus(ctx, familyID, y, m)
		if err != nil {
			return nil, err
		}
		return json.Marshal(res)

	case "get_card_projections":
		var params struct {
			MonthsAhead *int `json:"months_ahead"`
		}
		_ = json.Unmarshal(args, &params)

		months := 12
		if params.MonthsAhead != nil && *params.MonthsAhead > 0 {
			months = *params.MonthsAhead
		}

		res, err := r.creditPort.GetCardProjections(ctx, familyID, nil, months)
		if err != nil {
			return nil, err
		}
		return json.Marshal(res)

	default:
		return nil, fmt.Errorf("ferramenta desconhecida: %s", toolName)
	}
}
