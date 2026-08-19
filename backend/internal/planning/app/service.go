package app

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/db/sqlc"
	"github.com/enosads/prumo/backend/internal/planning/domain"
)

type PlanningService struct {
	queries *sqlc.Queries
	pool    *pgxpool.Pool
}

func NewPlanningService(queries *sqlc.Queries, pool *pgxpool.Pool) *PlanningService {
	return &PlanningService{
		queries: queries,
		pool:    pool,
	}
}

func (s *PlanningService) GetBudgetStatus(ctx context.Context, familyID uuid.UUID, year int16, month int16) (*domain.BudgetStatus, error) {
	if year == 0 || month == 0 {
		now := time.Now()
		year = int16(now.Year())
		month = int16(now.Month())
	}

	budget, err := s.queries.GetBudgetByPeriod(ctx, sqlc.GetBudgetByPeriodParams{
		FamilyID:    familyID,
		PeriodYear:  year,
		PeriodMonth: month,
	})
	if err != nil {
		budget, err = s.queries.CreateBudget(ctx, sqlc.CreateBudgetParams{
			FamilyID:            familyID,
			PeriodYear:          year,
			PeriodMonth:         month,
			TotalAllocatedCents: 0,
		})
		if err != nil {
			return nil, err
		}
	}

	startOfMonth := time.Date(int(year), time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0).Add(-time.Nanosecond)

	spendingRows, err := s.queries.GetCategorySpendingForPeriod(ctx, sqlc.GetCategorySpendingForPeriodParams{
		FamilyID:  familyID,
		StartDate: startOfMonth,
		EndDate:   endOfMonth,
	})
	if err != nil {
		return nil, err
	}

	spentByCategory := make(map[uuid.UUID]int64)
	for _, row := range spendingRows {
		if row.CategoryID != nil {
			spentByCategory[*row.CategoryID] = row.TotalSpentCents
		}
	}

	rawItems, err := s.queries.ListBudgetItems(ctx, budget.ID)
	if err != nil {
		return nil, err
	}

	var items []domain.BudgetItemDetail
	var totalSpentCents int64

	for _, it := range rawItems {
		spent := spentByCategory[it.CategoryID]
		totalSpentCents += spent

		var pct float64
		if it.AllocatedAmountCents > 0 {
			pct = (float64(spent) / float64(it.AllocatedAmountCents)) * 100.0
		}

		remaining := it.AllocatedAmountCents - spent
		status := domain.StatusNormal
		if pct >= 100.0 {
			status = domain.StatusExceeded
		} else if pct >= 80.0 {
			status = domain.StatusWarning
		}

		items = append(items, domain.BudgetItemDetail{
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

	totals, err := s.queries.GetMonthlyCashFlowTotals(ctx, sqlc.GetMonthlyCashFlowTotalsParams{
		FamilyID:  familyID,
		StartDate: startOfMonth,
		EndDate:   endOfMonth,
	})
	totalIncome := int64(0)
	if err == nil {
		totalIncome = totals.TotalIncomeCents
	}

	freeToInvest := totalIncome - budget.TotalAllocatedCents
	if freeToInvest < 0 {
		freeToInvest = 0
	}

	return &domain.BudgetStatus{
		ID:                  budget.ID,
		FamilyID:            budget.FamilyID,
		PeriodYear:          budget.PeriodYear,
		PeriodMonth:         budget.PeriodMonth,
		TotalAllocatedCents: budget.TotalAllocatedCents,
		Items:               items,
		Summary: domain.BudgetSummary{
			TotalIncomeCents:   totalIncome,
			TotalBudgetedCents: budget.TotalAllocatedCents,
			TotalSpentCents:    totalSpentCents,
			FreeToInvestCents:  freeToInvest,
		},
		CreatedAt: budget.CreatedAt,
	}, nil
}
