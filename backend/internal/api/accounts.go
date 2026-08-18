package api

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreateAccountInput struct {
	Body struct {
		Name                string  `json:"name" minLength:"2" doc:"Nome da conta (ex: Nubank, Itaú Corrente)"`
		Kind                string  `json:"kind" enum:"checking,savings,investment,cash,credit_card" doc:"Tipo da conta"`
		Visibility          string  `json:"visibility" enum:"shared,private" default:"shared" doc:"Visibilidade (compartilhada ou privada)"`
		Currency            string  `json:"currency" default:"BRL" doc:"Moeda"`
		InitialBalanceCents int64   `json:"initial_balance_cents" default:"0" doc:"Saldo inicial em centavos"`
		Color               *string `json:"color,omitempty" doc:"Cor hexadecimal para UI (ex: #820AD1)"`
	}
}

type CreateAccountOutput struct {
	Body struct {
		Account sqlc.Account `json:"account"`
	}
}

type ListAccountsOutput struct {
	Body struct {
		Accounts []sqlc.ListAccountsByFamilyIDRow `json:"accounts"`
	}
}

func (s *Server) registerAccountRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "createAccount",
		Method:      http.MethodPost,
		Path:        "/v1/accounts",
		Summary:     "Cria uma conta financeira no núcleo familiar",
		Tags:        []string{"Contas"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *CreateAccountInput) (*CreateAccountOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para criar contas")
		}

		currency := input.Body.Currency
		if currency == "" {
			currency = "BRL"
		}
		visibility := input.Body.Visibility
		if visibility == "" {
			visibility = "shared"
		}

		account, err := s.db.CreateAccount(ctx, sqlc.CreateAccountParams{
			FamilyID:            *uCtx.FamilyID,
			OwnerUserID:         uCtx.UserID,
			Name:                input.Body.Name,
			Kind:                input.Body.Kind,
			Visibility:          visibility,
			Currency:            currency,
			InitialBalanceCents: input.Body.InitialBalanceCents,
			CurrentBalanceCents: input.Body.InitialBalanceCents,
			Color:               input.Body.Color,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar conta financeira")
		}

		resp := &CreateAccountOutput{}
		resp.Body.Account = account
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listAccounts",
		Method:      http.MethodGet,
		Path:        "/v1/accounts",
		Summary:     "Lista as contas financeiras do núcleo familiar ativo",
		Tags:        []string{"Contas"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*ListAccountsOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		accounts, err := s.db.ListAccountsByFamilyID(ctx, *uCtx.FamilyID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar contas")
		}

		// Filtra contas privadas caso o membro não seja o dono nem admin
		filtered := make([]sqlc.ListAccountsByFamilyIDRow, 0, len(accounts))
		for _, acc := range accounts {
			if acc.Visibility == "private" && acc.OwnerUserID != uCtx.UserID && (uCtx.Role == nil || !authz.CanManageFamily(*uCtx.Role)) {
				continue
			}
			filtered = append(filtered, acc)
		}

		resp := &ListAccountsOutput{}
		resp.Body.Accounts = filtered
		return resp, nil
	})
}
