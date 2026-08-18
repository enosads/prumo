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
		Name     string     `json:"name" minLength:"2" doc:"Nome da categoria (ex: Alimentação, Moradia)"`
		Icon     *string    `json:"icon,omitempty" doc:"Nome do ícone SF Symbols (ex: cart.fill, house.fill)"`
		Color    *string    `json:"color,omitempty" doc:"Cor hexadecimal para UI (ex: #FF9500)"`
		Kind     string     `json:"kind,omitempty" enum:"income,expense,both" default:"expense" doc:"Tipo da categoria"`
		ParentID *uuid.UUID `json:"parent_id,omitempty" doc:"ID da categoria pai para hierarquia"`
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

type defaultCategorySeed struct {
	name  string
	icon  string
	color string
	kind  string
}

var defaultCategories = []defaultCategorySeed{
	{name: "Alimentação & Mercado", icon: "cart.fill", color: "#FF9500", kind: "expense"},
	{name: "Moradia & Contas", icon: "house.fill", color: "#007AFF", kind: "expense"},
	{name: "Transporte", icon: "car.fill", color: "#5856D6", kind: "expense"},
	{name: "Saúde & Farmácia", icon: "heart.fill", color: "#FF2D55", kind: "expense"},
	{name: "Lazer & Restaurantes", icon: "fork.knife", color: "#AF52DE", kind: "expense"},
	{name: "Educação", icon: "book.fill", color: "#34C759", kind: "expense"},
	{name: "Assinaturas & Serviços", icon: "play.tv.fill", color: "#5AC8FA", kind: "expense"},
	{name: "Outros Gastos", icon: "ellipsis.circle.fill", color: "#8E8E93", kind: "expense"},
	{name: "Salário & Proventos", icon: "banknote.fill", color: "#34C759", kind: "income"},
	{name: "Rendimentos & Investimentos", icon: "chart.line.uptrend.xyaxis", color: "#30B0C7", kind: "income"},
	{name: "Outras Receitas", icon: "plus.circle.fill", color: "#34C759", kind: "income"},
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

		category, err := s.db.CreateCategory(ctx, sqlc.CreateCategoryParams{
			FamilyID: *uCtx.FamilyID,
			Name:     input.Body.Name,
			Icon:     input.Body.Icon,
			Color:    input.Body.Color,
			Kind:     kind,
			ParentID: input.Body.ParentID,
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

		// Verifica se a família possui categorias; se não, faz seed inicial das categorias padrão
		count, err := s.db.CountCategoriesByFamilyID(ctx, *uCtx.FamilyID)
		if err == nil && count == 0 {
			for _, def := range defaultCategories {
				icon := def.icon
				color := def.color
				_, _ = s.db.CreateCategory(ctx, sqlc.CreateCategoryParams{
					FamilyID: *uCtx.FamilyID,
					Name:     def.name,
					Icon:     &icon,
					Color:    &color,
					Kind:     def.kind,
				})
			}
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
