package api

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreateCategoryInput struct {
	Body struct {
		Name       string     `json:"name" minLength:"2" doc:"Nome da categoria (ex: Alimentação, Moradia)"`
		Slug       *string    `json:"slug,omitempty" doc:"Slug canônico em inglês (ex: food, housing)"`
		Icon       *string    `json:"icon,omitempty" doc:"Nome do ícone SF Symbols (ex: cart.fill, house.fill)"`
		Color      *string    `json:"color,omitempty" doc:"Cor hexadecimal para UI (ex: #FF9500)"`
		Kind       string     `json:"kind,omitempty" enum:"income,expense,both" default:"expense" doc:"Tipo da categoria"`
		ParentID   *uuid.UUID `json:"parent_id,omitempty" doc:"ID da categoria pai para hierarquia"`
		SystemOnly *bool      `json:"system_only,omitempty" default:"false" doc:"Indica se é de uso exclusivo do sistema (ex: uncategorized)"`
	}
}

type CreateCategoryOutput struct {
	Body struct {
		Category sqlc.Category `json:"category"`
	}
}

type ListCategoriesOutput struct {
	Body struct {
		Categories []sqlc.Category `json:"categories"`
	}
}

type DeleteCategoryInput struct {
	ID uuid.UUID `path:"id" doc:"ID da categoria a ser excluída"`
}

func (s *Server) registerCategoryRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "createCategory",
		Method:      http.MethodPost,
		Path:        "/v1/categories",
		Summary:     "Cria uma categoria personalizada no núcleo familiar",
		Tags:        []string{"Categorias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *CreateCategoryInput) (*CreateCategoryOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para criar categorias")
		}

		kind := input.Body.Kind
		if kind == "" {
			kind = "expense"
		}

		systemOnly := false
		if input.Body.SystemOnly != nil {
			systemOnly = *input.Body.SystemOnly
		}

		category, err := s.db.CreateCategory(ctx, sqlc.CreateCategoryParams{
			FamilyID:   *uCtx.FamilyID,
			Name:       input.Body.Name,
			Icon:       input.Body.Icon,
			Color:      input.Body.Color,
			Kind:       kind,
			ParentID:   input.Body.ParentID,
			Slug:       input.Body.Slug,
			SystemOnly: systemOnly,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar categoria")
		}

		resp := &CreateCategoryOutput{}
		resp.Body.Category = category
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listCategories",
		Method:      http.MethodGet,
		Path:        "/v1/categories",
		Summary:     "Lista as categorias de transação do núcleo familiar",
		Tags:        []string{"Categorias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*ListCategoriesOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		// Garante que a família possui as 13 categorias raízes + uncategorized (ADR-0002)
		if err := s.ledger.EnsureSeedCategories(ctx, *uCtx.FamilyID); err != nil {
			s.log.Printf("[Categorias] Erro ao semear categorias: %v", err)
		}

		categories, err := s.db.ListCategoriesByFamilyID(ctx, *uCtx.FamilyID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar categorias")
		}

		resp := &ListCategoriesOutput{}
		resp.Body.Categories = categories
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteCategory",
		Method:      http.MethodDelete,
		Path:        "/v1/categories/{id}",
		Summary:     "Exclui uma categoria do núcleo familiar",
		Tags:        []string{"Categorias"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *DeleteCategoryInput) (*struct{}, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para excluir categorias")
		}

		err = s.db.DeleteCategory(ctx, sqlc.DeleteCategoryParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao excluir categoria")
		}

		return &struct{}{}, nil
	})
}
