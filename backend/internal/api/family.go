package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreateFamilyInput struct {
	Body struct {
		Name         string `json:"name" minLength:"2" doc:"Nome do núcleo familiar"`
		BaseCurrency string `json:"base_currency" default:"BRL" doc:"Moeda base (BRL, USD)"`
	}
}

type CreateFamilyOutput struct {
	Body struct {
		Family sqlc.Family `json:"family"`
	}
}

type ListFamiliesOutput struct {
	Body struct {
		Families []sqlc.ListFamiliesByUserIDRow `json:"families"`
	}
}

type ListMembersInput struct {
	FamilyID uuid.UUID `path:"id" doc:"ID do núcleo familiar"`
}

type ListMembersOutput struct {
	Body struct {
		Members []sqlc.ListFamilyMembersRow `json:"members"`
	}
}

type InviteMemberInput struct {
	FamilyID uuid.UUID `path:"id" doc:"ID do núcleo familiar"`
	Body     struct {
		Email string `json:"email" format:"email" doc:"E-mail da pessoa convidada"`
		Role  string `json:"role" enum:"admin,member,viewer" default:"member" doc:"Papel atribuído"`
	}
}

type InviteMemberOutput struct {
	Body struct {
		Invitation sqlc.FamilyInvitation `json:"invitation"`
	}
}

func (s *Server) registerFamilyRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "createFamily",
		Method:      http.MethodPost,
		Path:        "/v1/families",
		Summary:     "Cria um novo núcleo familiar",
		Tags:        []string{"Famílias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *CreateFamilyInput) (*CreateFamilyOutput, error) {
		uCtx, err := requireAuth(ctx)
		if err != nil {
			return nil, err
		}

		currency := input.Body.BaseCurrency
		if currency == "" {
			currency = "BRL"
		}

		family, err := s.db.CreateFamily(ctx, sqlc.CreateFamilyParams{
			Name:         input.Body.Name,
			BaseCurrency: currency,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar família")
		}

		roleOwner := authz.RoleOwner
		_, err = s.db.AddFamilyMember(ctx, sqlc.AddFamilyMemberParams{
			FamilyID: family.ID,
			UserID:   uCtx.UserID,
			Role:     roleOwner,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao vincular criador à família")
		}

		resp := &CreateFamilyOutput{}
		resp.Body.Family = family
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listFamilies",
		Method:      http.MethodGet,
		Path:        "/v1/families",
		Summary:     "Lista os núcleos familiares do usuário logado",
		Tags:        []string{"Famílias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*ListFamiliesOutput, error) {
		uCtx, err := requireAuth(ctx)
		if err != nil {
			return nil, err
		}

		families, err := s.db.ListFamiliesByUserID(ctx, uCtx.UserID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar famílias")
		}

		resp := &ListFamiliesOutput{}
		resp.Body.Families = families
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listFamilyMembers",
		Method:      http.MethodGet,
		Path:        "/v1/families/{id}/members",
		Summary:     "Lista os membros de um núcleo familiar",
		Tags:        []string{"Famílias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *ListMembersInput) (*ListMembersOutput, error) {
		uCtx, err := requireAuth(ctx)
		if err != nil {
			return nil, err
		}

		role, err := s.db.GetFamilyMemberRole(ctx, sqlc.GetFamilyMemberRoleParams{
			FamilyID: input.FamilyID,
			UserID:   uCtx.UserID,
		})
		if err != nil || !authz.CanViewFinancials(role) {
			return nil, httpErrorForbidden("Você não é membro desta família")
		}

		members, err := s.db.ListFamilyMembers(ctx, input.FamilyID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar membros da família")
		}

		resp := &ListMembersOutput{}
		resp.Body.Members = members
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "inviteFamilyMember",
		Method:      http.MethodPost,
		Path:        "/v1/families/{id}/invitations",
		Summary:     "Gera convite para adicionar membro ao núcleo familiar",
		Tags:        []string{"Famílias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *InviteMemberInput) (*InviteMemberOutput, error) {
		uCtx, err := requireAuth(ctx)
		if err != nil {
			return nil, err
		}

		role, err := s.db.GetFamilyMemberRole(ctx, sqlc.GetFamilyMemberRoleParams{
			FamilyID: input.FamilyID,
			UserID:   uCtx.UserID,
		})
		if err != nil || !authz.CanManageFamily(role) {
			return nil, httpErrorForbidden("Apenas administradores e proprietários podem convidar membros")
		}

		inviteBytes := make([]byte, 16)
		if _, err := rand.Read(inviteBytes); err != nil {
			return nil, httpErrorInternal("Erro ao gerar código de convite")
		}
		inviteCode := hex.EncodeToString(inviteBytes)

		expiresAt := time.Now().Add(7 * 24 * time.Hour) // 7 dias
		invitation, err := s.db.CreateFamilyInvitation(ctx, sqlc.CreateFamilyInvitationParams{
			FamilyID:        input.FamilyID,
			InvitedByUserID: uCtx.UserID,
			Email:           input.Body.Email,
			Role:            input.Body.Role,
			InviteCode:      inviteCode,
			ExpiresAt:       expiresAt,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao registrar convite")
		}

		resp := &InviteMemberOutput{}
		resp.Body.Invitation = invitation
		return resp, nil
	})
}
