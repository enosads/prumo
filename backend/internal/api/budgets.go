package api

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type GetBudgetInput struct {
	Year  *int `query:"year" doc:"Ano do orçamento (padrão: ano atual)"`
	Month *int `query:"month" doc:"Mês do orçamento (1-12, padrão: mês atual)"`
}

type BudgetItemDetail struct {
	ID                   uuid.UUID `json:"id"`
	BudgetID             uuid.UUID `json:"budget_id"`
	CategoryID           uuid.UUID `json:"category_id"`
	CategoryName         string    `json:"category_name"`
	CategoryIcon         *string   `json:"category_icon,omitempty"`
	CategoryColor        *string   `json:"category_color,omitempty"`
	CategoryKind         string    `json:"category_kind"`
	AllocatedAmountCents int64     `json:"allocated_amount_cents"`
	SpentAmountCents     int64     `json:"spent_amount_cents"`
	SpentPercentage      float64   `json:"spent_percentage"`
	RemainingCents       int64     `json:"remaining_cents"`
	Status               string    `json:"status"` // "normal" (<75%), "warning" (75-100%), "exceeded" (>100%)
	RolloverEnabled      bool      `json:"rollover_enabled"`
}

type BudgetSummaryData struct {
	TotalIncomeCents   int64 `json:"total_income_cents"`
	TotalBudgetedCents int64 `json:"total_budgeted_cents"`
	TotalSpentCents    int64 `json:"total_spent_cents"`
	FreeToInvestCents  int64 `json:"free_to_invest_cents"`
}

type GetBudgetOutput struct {
	Body struct {
		Budget  sqlc.Budget          `json:"budget"`
		Items   []BudgetItemDetail   `json:"items"`
		Summary BudgetSummaryData    `json:"summary"`
	}
}

type UpsertBudgetItemInput struct {
	ID   uuid.UUID `path:"id" doc:"ID do orçamento"`
	Body struct {
		CategoryID           uuid.UUID `json:"category_id" doc:"ID da categoria"`
		AllocatedAmountCents int64     `json:"allocated_amount_cents" minimum:"0" doc:"Teto alocado em centavos"`
		RolloverEnabled      bool      `json:"rollover_enabled" default:"false" doc:"Permite acúmulo de saldo para o mês seguinte"`
	}
}

type UpsertBudgetItemOutput struct {
	Body struct {
		Item   sqlc.BudgetItem `json:"item"`
		Budget sqlc.Budget     `json:"budget"`
	}
}

type DeleteBudgetItemInput struct {
	ID         uuid.UUID `path:"id" doc:"ID do orçamento"`
	CategoryID uuid.UUID `path:"categoryId" doc:"ID da categoria"`
}

func (s *Server) registerBudgetRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "getBudget",
		Method:      http.MethodGet,
		Path:        "/v1/budgets",
		Summary:     "Consulta os envelopes orçamentários do mês com realizado vs. orçado",
		Tags:        []string{"Orçamentos"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *GetBudgetInput) (*GetBudgetOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		now := time.Now()
		year := now.Year()
		month := int(now.Month())
		if input.Year != nil && *input.Year > 0 {
			year = *input.Year
		}
		if input.Month != nil && *input.Month >= 1 && *input.Month <= 12 {
			month = *input.Month
		}

		budget, err := s.db.GetBudgetByPeriod(ctx, sqlc.GetBudgetByPeriodParams{
			FamilyID:    *uCtx.FamilyID,
			PeriodYear:  int16(year),
			PeriodMonth: int16(month),
		})
		if err != nil {
			// Cria o orçamento inicial para o mês
			budget, err = s.db.CreateBudget(ctx, sqlc.CreateBudgetParams{
				FamilyID:            *uCtx.FamilyID,
				PeriodYear:          int16(year),
				PeriodMonth:         int16(month),
				TotalAllocatedCents: 0,
			})
			if err != nil {
				return nil, httpErrorInternal("Erro ao inicializar orçamento")
			}
		}

		items, err := s.db.ListBudgetItems(ctx, budget.ID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar itens do orçamento")
		}

		// Período do mês
		startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
		endOfMonth := startOfMonth.AddDate(0, 1, 0).Add(-time.Nanosecond)

		// Busca gastos reais por categoria no mês
		categorySpendings, err := s.db.GetCategorySpendingForPeriod(ctx, sqlc.GetCategorySpendingForPeriodParams{
			FamilyID:  *uCtx.FamilyID,
			StartDate: startOfMonth,
			EndDate:   endOfMonth,
		})
		spendingMap := make(map[uuid.UUID]int64)
		if err == nil {
			for _, cs := range categorySpendings {
				if cs.CategoryID != nil {
					spendingMap[*cs.CategoryID] = cs.TotalSpentCents
				}
			}
		}

		var detailedItems []BudgetItemDetail
		var totalSpent int64

		for _, it := range items {
			spent := spendingMap[it.CategoryID]
			totalSpent += spent
			remaining := it.AllocatedAmountCents - spent

			pct := 0.0
			if it.AllocatedAmountCents > 0 {
				pct = (float64(spent) / float64(it.AllocatedAmountCents)) * 100.0
			}

			status := "normal"
			if pct >= 100.0 {
				status = "exceeded"
			} else if pct >= 75.0 {
				status = "warning"
			}

			detailedItems = append(detailedItems, BudgetItemDetail{
				ID:                   it.ID,
				BudgetID:             it.BudgetID,
				CategoryID:           it.CategoryID,
				CategoryName:         it.CategoryName,
				CategoryIcon:         it.CategoryIcon,
				CategoryColor:        it.CategoryColor,
				CategoryKind:         it.CategoryKind,
				AllocatedAmountCents: it.AllocatedAmountCents,
				SpentAmountCents:     spent,
				SpentPercentage:      pct,
				RemainingCents:       remaining,
				Status:               status,
				RolloverEnabled:      it.RolloverEnabled,
			})
		}

		// Totais gerais do fluxo de caixa no mês
		cfTotals, _ := s.db.GetMonthlyCashFlowTotals(ctx, sqlc.GetMonthlyCashFlowTotalsParams{
			FamilyID:  *uCtx.FamilyID,
			StartDate: startOfMonth,
			EndDate:   endOfMonth,
		})

		freeToInvest := cfTotals.TotalIncomeCents - budget.TotalAllocatedCents
		if freeToInvest < 0 {
			freeToInvest = 0
		}

		resp := &GetBudgetOutput{}
		resp.Body.Budget = budget
		resp.Body.Items = detailedItems
		resp.Body.Summary = BudgetSummaryData{
			TotalIncomeCents:   cfTotals.TotalIncomeCents,
			TotalBudgetedCents: budget.TotalAllocatedCents,
			TotalSpentCents:    totalSpent,
			FreeToInvestCents:  freeToInvest,
		}
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "upsertBudgetItem",
		Method:      http.MethodPut,
		Path:        "/v1/budgets/{id}/items",
		Summary:     "Define ou atualiza o teto orçamentário de uma categoria (envelope)",
		Tags:        []string{"Orçamentos"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *UpsertBudgetItemInput) (*UpsertBudgetItemOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para alterar orçamento")
		}

		budget, err := s.db.GetBudgetByID(ctx, sqlc.GetBudgetByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Orçamento não encontrado")
		}

		item, err := s.db.UpsertBudgetItem(ctx, sqlc.UpsertBudgetItemParams{
			BudgetID:             budget.ID,
			CategoryID:           input.Body.CategoryID,
			AllocatedAmountCents: input.Body.AllocatedAmountCents,
			RolloverEnabled:      input.Body.RolloverEnabled,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao salvar envelope orçamentário")
		}

		updatedBudget, err := s.db.UpdateBudgetTotalAllocated(ctx, sqlc.UpdateBudgetTotalAllocatedParams{
			BudgetID: budget.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao atualizar total do orçamento")
		}

		resp := &UpsertBudgetItemOutput{}
		resp.Body.Item = item
		resp.Body.Budget = updatedBudget
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteBudgetItem",
		Method:      http.MethodDelete,
		Path:        "/v1/budgets/{id}/items/{categoryId}",
		Summary:     "Remove uma categoria do orçamento mensal",
		Tags:        []string{"Orçamentos"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *DeleteBudgetItemInput) (*struct{}, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para alterar orçamento")
		}

		budget, err := s.db.GetBudgetByID(ctx, sqlc.GetBudgetByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Orçamento não encontrado")
		}

		err = s.db.DeleteBudgetItem(ctx, sqlc.DeleteBudgetItemParams{
			BudgetID:   budget.ID,
			CategoryID: input.CategoryID,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao remover item do orçamento")
		}

		_, _ = s.db.UpdateBudgetTotalAllocated(ctx, sqlc.UpdateBudgetTotalAllocatedParams{
			BudgetID: budget.ID,
			FamilyID: *uCtx.FamilyID,
		})

		return &struct{}{}, nil
	})
}
