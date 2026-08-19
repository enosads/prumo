package domain

import (
	"context"

	"github.com/google/uuid"
)

type CreditPort interface {
	GetCardProjections(ctx context.Context, familyID uuid.UUID, cardID *uuid.UUID, monthsAhead int) ([]CardProjectionSummary, error)
	ListCreditCards(ctx context.Context, familyID uuid.UUID) ([]CreditCard, error)
}
