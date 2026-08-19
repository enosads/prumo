package domain

import (
	"time"

	"github.com/google/uuid"
)

type BudgetItemStatus string

const (
	StatusNormal   BudgetItemStatus = "normal"
	StatusWarning  BudgetItemStatus = "warning"
	StatusExceeded BudgetItemStatus = "exceeded"
)

type BudgetItemDetail struct {
	ID                   uuid.UUID
	BudgetID             uuid.UUID
	CategoryID           uuid.UUID
	CategoryName         string
	CategorySlug         *string
	CategoryIcon         *string
	CategoryColor        *string
	CategoryKind         string
	AllocatedAmountCents int64
	SpentAmountCents     int64
	SpentPercentage      float64
	RemainingCents       int64
	Status               BudgetItemStatus
	RolloverEnabled      bool
}

type BudgetSummary struct {
	TotalIncomeCents   int64
	TotalBudgetedCents int64
	TotalSpentCents    int64
	FreeToInvestCents  int64
}

type BudgetStatus struct {
	ID                 uuid.UUID
	FamilyID           uuid.UUID
	PeriodYear         int16
	PeriodMonth        int16
	TotalAllocatedCents int64
	Items              []BudgetItemDetail
	Summary            BudgetSummary
	CreatedAt          time.Time
}
