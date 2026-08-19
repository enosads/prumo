package domain

import (
	"context"

	"github.com/google/uuid"
)

type IdentityPort interface {
	GetUserByID(ctx context.Context, id uuid.UUID) (*User, error)
	GetFamilyByID(ctx context.Context, id uuid.UUID) (*Family, error)
	ListFamilyMembers(ctx context.Context, familyID uuid.UUID) ([]FamilyMember, error)
}
