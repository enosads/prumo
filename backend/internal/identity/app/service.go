package app

import (
	"context"

	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/db/sqlc"
	"github.com/enosads/prumo/backend/internal/identity/domain"
)

type IdentityService struct {
	queries *sqlc.Queries
}

func NewIdentityService(queries *sqlc.Queries) *IdentityService {
	return &IdentityService{
		queries: queries,
	}
}

func (s *IdentityService) GetUserByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	u, err := s.queries.GetUserByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &domain.User{
		ID:        u.ID,
		Email:     u.Email,
		FullName:  u.FullName,
		AvatarURL: u.AvatarUrl,
		IsActive:  u.IsActive,
		CreatedAt: u.CreatedAt,
		UpdatedAt: u.UpdatedAt,
	}, nil
}

func (s *IdentityService) GetFamilyByID(ctx context.Context, id uuid.UUID) (*domain.Family, error) {
	f, err := s.queries.GetFamilyByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &domain.Family{
		ID:           f.ID,
		Name:         f.Name,
		BaseCurrency: f.BaseCurrency,
		CreatedAt:    f.CreatedAt,
		UpdatedAt:    f.UpdatedAt,
	}, nil
}

func (s *IdentityService) ListFamilyMembers(ctx context.Context, familyID uuid.UUID) ([]domain.FamilyMember, error) {
	raw, err := s.queries.ListFamilyMembers(ctx, familyID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.FamilyMember, len(raw))
	for i, m := range raw {
		out[i] = domain.FamilyMember{
			ID:        m.ID,
			FamilyID:  m.FamilyID,
			UserID:    m.UserID,
			Role:      domain.Role(m.Role),
			Nickname:  m.Nickname,
			JoinedAt:  m.JoinedAt,
			Email:     m.Email,
			FullName:  m.FullName,
			AvatarURL: m.AvatarUrl,
		}
	}
	return out, nil
}
