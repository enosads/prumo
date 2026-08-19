package copilot

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/copilot/adapter/llm"
	"github.com/enosads/prumo/backend/internal/copilot/app"
	"github.com/enosads/prumo/backend/internal/copilot/domain"
	creditDomain "github.com/enosads/prumo/backend/internal/credit/domain"
	ledgerDomain "github.com/enosads/prumo/backend/internal/ledger/domain"
	planningDomain "github.com/enosads/prumo/backend/internal/planning/domain"
)

type mockLedgerPort struct{}

func (m *mockLedgerPort) GetConsolidatedNetWorth(ctx context.Context, familyID uuid.UUID) (*ledgerDomain.NetWorthSummary, error) {
	return &ledgerDomain.NetWorthSummary{
		TotalNetWorthCents: 500000,
		CheckingCents:      200000,
		SavingsCents:       300000,
	}, nil
}

func (m *mockLedgerPort) QueryCashFlow(ctx context.Context, filter ledgerDomain.CashFlowFilter) (*ledgerDomain.CashFlowSummary, error) {
	return &ledgerDomain.CashFlowSummary{
		TotalIncomeCents:  800000,
		TotalExpenseCents: 250000,
		NetCashFlowCents:  550000,
	}, nil
}

func (m *mockLedgerPort) ListCategories(ctx context.Context, familyID uuid.UUID, includeSystem bool) ([]ledgerDomain.Category, error) {
	return nil, nil
}

func (m *mockLedgerPort) GetCategoryBySlug(ctx context.Context, familyID uuid.UUID, slug string) (*ledgerDomain.Category, error) {
	return nil, nil
}

func (m *mockLedgerPort) EnsureSeedCategories(ctx context.Context, familyID uuid.UUID) error {
	return nil
}

type mockCreditPort struct{}

func (m *mockCreditPort) GetCardProjections(ctx context.Context, familyID uuid.UUID, cardID *uuid.UUID, monthsAhead int) ([]creditDomain.CardProjectionSummary, error) {
	return []creditDomain.CardProjectionSummary{
		{
			CardID:           uuid.New(),
			CardName:         "Nubank UV",
			CreditLimitCents: 1000000,
			UsedLimitCents:   150000,
		},
	}, nil
}

func (m *mockCreditPort) ListCreditCards(ctx context.Context, familyID uuid.UUID) ([]creditDomain.CreditCard, error) {
	return nil, nil
}

type mockPlanningPort struct{}

func (m *mockPlanningPort) GetBudgetStatus(ctx context.Context, familyID uuid.UUID, year int16, month int16) (*planningDomain.BudgetStatus, error) {
	return &planningDomain.BudgetStatus{
		Summary: planningDomain.BudgetSummary{
			TotalIncomeCents:   800000,
			TotalBudgetedCents: 500000,
			TotalSpentCents:    250000,
			FreeToInvestCents:  300000,
		},
	}, nil
}

func TestCopilot_FallbackProviderAndTools(t *testing.T) {
	tools := app.NewToolRegistry(&mockLedgerPort{}, &mockCreditPort{}, &mockPlanningPort{})
	fallback := llm.NewFallbackProvider()
	ctx := context.Background()

	// 1. Pergunta sobre patrimônio deve disparar get_consolidated_net_worth
	messages := []llm.LLMMessage{
		{Role: "user", Content: "Qual é o patrimônio consolidado da família?"},
	}
	resp, err := fallback.Chat(ctx, "", messages, tools.GetToolDefinitions())
	if err != nil {
		t.Fatalf("Chat error: %v", err)
	}

	if len(resp.ToolCalls) == 0 {
		t.Fatalf("Expected tool call, got 0")
	}

	if resp.ToolCalls[0].Name != "get_consolidated_net_worth" {
		t.Fatalf("Expected tool get_consolidated_net_worth, got %s", resp.ToolCalls[0].Name)
	}

	// 2. Executa a tool
	rawResult, err := tools.ExecuteTool(ctx, uuid.New(), uuid.New(), resp.ToolCalls[0].Name, resp.ToolCalls[0].Arguments)
	if err != nil {
		t.Fatalf("ExecuteTool error: %v", err)
	}

	// 3. Passa o resultado da tool de volta ao fallback
	tcID := resp.ToolCalls[0].ID
	messages = append(messages,
		llm.LLMMessage{Role: "assistant", ToolCalls: resp.ToolCalls},
		llm.LLMMessage{Role: "tool", Content: string(rawResult), ToolCallID: &tcID},
	)

	finalResp, err := fallback.Chat(ctx, "", messages, tools.GetToolDefinitions())
	if err != nil {
		t.Fatalf("Final Chat error: %v", err)
	}

	if len(finalResp.ToolCalls) > 0 {
		t.Fatalf("Expected final text, got more tool calls")
	}

	if finalResp.Content == "" {
		t.Fatalf("Expected content, got empty string")
	}
}

func TestCopilot_StreamingDeltaTypes(t *testing.T) {
	delta := domain.ChatStreamDelta{
		Type: domain.DeltaMessageStart,
	}
	if delta.Type != domain.DeltaMessageStart {
		t.Errorf("unexpected delta type")
	}
}
