package domain

import (
	"context"

	"github.com/google/uuid"
)

type PlanningPort interface {
	GetBudgetStatus(ctx context.Context, familyID uuid.UUID, year int16, month int16) (*BudgetStatus, error)
}
