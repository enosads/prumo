package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type CashFlowFilter struct {
	FamilyID     uuid.UUID
	AccountID    *uuid.UUID
	CategoryID   *uuid.UUID
	CategorySlug *string
	Kind         *string
	UserID       *uuid.UUID
	FromDate     *time.Time
	ToDate       *time.Time
	Limit        int
	Offset       int
}

type CashFlowSummary struct {
	TotalIncomeCents  int64
	TotalExpenseCents int64
	NetCashFlowCents  int64
	Transactions      []Transaction
}

type LedgerPort interface {
	GetConsolidatedNetWorth(ctx context.Context, familyID uuid.UUID) (*NetWorthSummary, error)
	QueryCashFlow(ctx context.Context, filter CashFlowFilter) (*CashFlowSummary, error)
	ListCategories(ctx context.Context, familyID uuid.UUID, includeSystem bool) ([]Category, error)
	GetCategoryBySlug(ctx context.Context, familyID uuid.UUID, slug string) (*Category, error)
	EnsureSeedCategories(ctx context.Context, familyID uuid.UUID) error
}
