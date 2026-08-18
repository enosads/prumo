package api

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreateTransactionInput struct {
	Body struct {
		AccountID            uuid.UUID  `json:"account_id" doc:"ID da conta de origem/lançamento"`
		CategoryID           *uuid.UUID `json:"category_id,omitempty" doc:"ID da categoria"`
		DestinationAccountID *uuid.UUID `json:"destination_account_id,omitempty" doc:"ID da conta de destino (obrigatório se kind=transfer)"`
		TargetUserID         *uuid.UUID `json:"target_user_id,omitempty" doc:"Membro da família responsável pelo gasto"`
		Kind                 string     `json:"kind" enum:"income,expense,transfer" doc:"Tipo da transação"`
		AmountCents          int64      `json:"amount_cents" minimum:"1" doc:"Valor em centavos"`
		Description          string     `json:"description" minLength:"1" doc:"Descrição da transação"`
		TransactedAt         *time.Time `json:"transacted_at,omitempty" doc:"Data/hora do lançamento"`
		Status               string     `json:"status" enum:"pending,completed,cancelled" default:"completed" doc:"Status"`
		InstallmentTotal     int        `json:"installment_total" default:"1" minimum:"1" maximum:"72" doc:"Número total de parcelas (para compras parceladas)"`
		CreditCardInvoiceID  *uuid.UUID `json:"credit_card_invoice_id,omitempty" doc:"ID da fatura de cartão vinculada"`
		Tags                 []string   `json:"tags,omitempty" doc:"Tags para busca e agrupamento"`
		Notes                *string    `json:"notes,omitempty" doc:"Observações adicionais"`
	}
}

type CreateTransactionOutput struct {
	Body struct {
		Transaction  sqlc.Transaction   `json:"transaction"`
		Installments []sqlc.Transaction `json:"installments,omitempty"`
	}
}

type ListTransactionsInput struct {
	AccountID  *uuid.UUID `query:"account_id" doc:"Filtrar por conta"`
	CategoryID *uuid.UUID `query:"category_id" doc:"Filtrar por categoria"`
	Kind       *string    `query:"kind" doc:"Filtrar por tipo (income, expense, transfer)"`
	UserID     *uuid.UUID `query:"user_id" doc:"Filtrar por membro da família"`
	From       *time.Time `query:"from" doc:"Data inicial"`
	To         *time.Time `query:"to" doc:"Data final"`
	Limit      int        `query:"limit" default:"50" doc:"Limite de registros"`
	Offset     int        `query:"offset" default:"0" doc:"Offset de paginação"`
}

type ListTransactionsOutput struct {
	Body struct {
		Transactions []sqlc.ListTransactionsByFamilyIDWithFiltersRow `json:"transactions"`
		Totals       *MonthlyCashFlowSummary                          `json:"totals,omitempty"`
	}
}

type MonthlyCashFlowSummary struct {
	TotalIncomeCents  int64 `json:"total_income_cents"`
	TotalExpenseCents int64 `json:"total_expense_cents"`
	NetCashFlowCents  int64 `json:"net_cash_flow_cents"`
}

type GetTransactionInput struct {
	ID uuid.UUID `path:"id" doc:"ID da transação"`
}

type GetTransactionOutput struct {
	Body struct {
		Transaction sqlc.GetTransactionByIDRow `json:"transaction"`
	}
}

type DeleteTransactionInput struct {
	ID uuid.UUID `path:"id" doc:"ID da transação"`
}

func (s *Server) registerTransactionRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "createTransaction",
		Method:      http.MethodPost,
		Path:        "/v1/transactions",
		Summary:     "Lança uma nova receita, despesa, transferência ou compra parcelada",
		Tags:        []string{"Transações"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *CreateTransactionInput) (*CreateTransactionOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para registrar transações")
		}

		// Valida a existência da conta
		account, err := s.db.GetAccountByID(ctx, sqlc.GetAccountByIDParams{
			ID:       input.Body.AccountID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Conta não encontrada no núcleo familiar")
		}

		transactedAt := time.Now()
		if input.Body.TransactedAt != nil && !input.Body.TransactedAt.IsZero() {
			transactedAt = *input.Body.TransactedAt
		}

		status := input.Body.Status
		if status == "" {
			status = "completed"
		}

		tags := input.Body.Tags
		if tags == nil {
			tags = []string{}
		}

		installmentTotal := input.Body.InstallmentTotal
		if installmentTotal <= 0 {
			installmentTotal = 1
		}

		// Se for transferência
		if input.Body.Kind == "transfer" {
			if input.Body.DestinationAccountID == nil || *input.Body.DestinationAccountID == uuid.Nil {
				return nil, httpErrorBadRequest("Conta de destino é obrigatória para transferências")
			}
			if *input.Body.DestinationAccountID == input.Body.AccountID {
				return nil, httpErrorBadRequest("A conta de destino não pode ser igual à conta de origem")
			}

			destAccount, err := s.db.GetAccountByID(ctx, sqlc.GetAccountByIDParams{
				ID:       *input.Body.DestinationAccountID,
				FamilyID: *uCtx.FamilyID,
			})
			if err != nil {
				return nil, httpErrorNotFound("Conta de destino não encontrada")
			}

			// Atualiza saldos atomicamente
			if status == "completed" {
				_, err = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
					ID:                  account.ID,
					FamilyID:            *uCtx.FamilyID,
					CurrentBalanceCents: -input.Body.AmountCents,
				})
				if err != nil {
					return nil, httpErrorInternal("Erro ao debitar conta de origem")
				}

				_, err = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
					ID:                  destAccount.ID,
					FamilyID:            *uCtx.FamilyID,
					CurrentBalanceCents: input.Body.AmountCents,
				})
				if err != nil {
					return nil, httpErrorInternal("Erro ao creditar conta de destino")
				}
			}

			tx, err := s.db.CreateTransaction(ctx, sqlc.CreateTransactionParams{
				FamilyID:            *uCtx.FamilyID,
				AccountID:           account.ID,
				CategoryID:          input.Body.CategoryID,
				CreatedByUserID:     uCtx.UserID,
				TargetUserID:        input.Body.TargetUserID,
				Kind:                "transfer",
				AmountCents:         input.Body.AmountCents,
				Description:         input.Body.Description,
				TransactedAt:        transactedAt,
				Status:              status,
				CreditCardInvoiceID: nil,
				InstallmentNumber:   ptrInt16(1),
				InstallmentTotal:    ptrInt16(1),
				InstallmentGroupID:  nil,
				Tags:                tags,
				Notes:               input.Body.Notes,
			})
			if err != nil {
				return nil, httpErrorInternal("Erro ao criar transação de transferência")
			}

			resp := &CreateTransactionOutput{}
			resp.Body.Transaction = tx
			return resp, nil
		}

		// Se for compra parcelada (N > 1)
		if installmentTotal > 1 {
			groupID := uuid.New()
			baseAmount := input.Body.AmountCents / int64(installmentTotal)
			remainder := input.Body.AmountCents % int64(installmentTotal)

			var createdInstallments []sqlc.Transaction

			for i := 1; i <= installmentTotal; i++ {
				instAmount := baseAmount
				if i == 1 {
					instAmount += remainder
				}

				instDate := transactedAt.AddDate(0, i-1, 0)
				instNum := int16(i)
				instTot := int16(installmentTotal)

				// Se conta for de cartão, busca/cria a fatura do período correspondente
				var invoiceID *uuid.UUID
				if input.Body.CreditCardInvoiceID != nil && i == 1 {
					invoiceID = input.Body.CreditCardInvoiceID
				}

				tx, err := s.db.CreateTransaction(ctx, sqlc.CreateTransactionParams{
					FamilyID:            *uCtx.FamilyID,
					AccountID:           account.ID,
					CategoryID:          input.Body.CategoryID,
					CreatedByUserID:     uCtx.UserID,
					TargetUserID:        input.Body.TargetUserID,
					Kind:                input.Body.Kind,
					AmountCents:         instAmount,
					Description:         input.Body.Description,
					TransactedAt:        instDate,
					Status:              status,
					CreditCardInvoiceID: invoiceID,
					InstallmentNumber:   &instNum,
					InstallmentTotal:    &instTot,
					InstallmentGroupID:  &groupID,
					Tags:                tags,
					Notes:               input.Body.Notes,
				})
				if err != nil {
					return nil, httpErrorInternal("Erro ao criar parcelas da transação")
				}
				createdInstallments = append(createdInstallments, tx)
			}

			// Atualiza saldo da conta para a primeira parcela se for despesa em conta corrente
			if status == "completed" && account.Kind != "credit_card" {
				delta := -createdInstallments[0].AmountCents
				if input.Body.Kind == "income" {
					delta = createdInstallments[0].AmountCents
				}
				_, _ = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
					ID:                  account.ID,
					FamilyID:            *uCtx.FamilyID,
					CurrentBalanceCents: delta,
				})
			}

			resp := &CreateTransactionOutput{}
			resp.Body.Transaction = createdInstallments[0]
			resp.Body.Installments = createdInstallments
			return resp, nil
		}

		// Transação avulsa comum (Receita ou Despesa)
		if status == "completed" && account.Kind != "credit_card" {
			delta := -input.Body.AmountCents
			if input.Body.Kind == "income" {
				delta = input.Body.AmountCents
			}
			_, err = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
				ID:                  account.ID,
				FamilyID:            *uCtx.FamilyID,
				CurrentBalanceCents: delta,
			})
			if err != nil {
				return nil, httpErrorInternal("Erro ao atualizar saldo da conta")
			}
		}

		tx, err := s.db.CreateTransaction(ctx, sqlc.CreateTransactionParams{
			FamilyID:            *uCtx.FamilyID,
			AccountID:           account.ID,
			CategoryID:          input.Body.CategoryID,
			CreatedByUserID:     uCtx.UserID,
			TargetUserID:        input.Body.TargetUserID,
			Kind:                input.Body.Kind,
			AmountCents:         input.Body.AmountCents,
			Description:         input.Body.Description,
			TransactedAt:        transactedAt,
			Status:              status,
			CreditCardInvoiceID: input.Body.CreditCardInvoiceID,
			InstallmentNumber:   ptrInt16(1),
			InstallmentTotal:    ptrInt16(1),
			InstallmentGroupID:  nil,
			Tags:                tags,
			Notes:               input.Body.Notes,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar transação")
		}

		resp := &CreateTransactionOutput{}
		resp.Body.Transaction = tx
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listTransactions",
		Method:      http.MethodGet,
		Path:        "/v1/transactions",
		Summary:     "Lista o extrato de transações com filtros por período, conta, categoria e membro",
		Tags:        []string{"Transações"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *ListTransactionsInput) (*ListTransactionsOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		limit := int32(input.Limit)
		if limit <= 0 {
			limit = 50
		}
		offset := int32(input.Offset)
		if offset < 0 {
			offset = 0
		}

		txs, err := s.db.ListTransactionsByFamilyIDWithFilters(ctx, sqlc.ListTransactionsByFamilyIDWithFiltersParams{
			FamilyID:    *uCtx.FamilyID,
			AccountID:   input.AccountID,
			CategoryID:  input.CategoryID,
			Kind:        input.Kind,
			UserID:      input.UserID,
			FromDate:    input.From,
			ToDate:      input.To,
			OffsetCount: offset,
			LimitCount:  limit,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar transações")
		}

		// Calcula totais do período se from e to estiverem preenchidos
		var totals *MonthlyCashFlowSummary
		if input.From != nil && input.To != nil {
			cfTotals, err := s.db.GetMonthlyCashFlowTotals(ctx, sqlc.GetMonthlyCashFlowTotalsParams{
				FamilyID:  *uCtx.FamilyID,
				StartDate: *input.From,
				EndDate:   *input.To,
			})
			if err == nil {
				totals = &MonthlyCashFlowSummary{
					TotalIncomeCents:  cfTotals.TotalIncomeCents,
					TotalExpenseCents: cfTotals.TotalExpenseCents,
					NetCashFlowCents:  cfTotals.TotalIncomeCents - cfTotals.TotalExpenseCents,
				}
			}
		}

		resp := &ListTransactionsOutput{}
		resp.Body.Transactions = txs
		resp.Body.Totals = totals
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getTransaction",
		Method:      http.MethodGet,
		Path:        "/v1/transactions/{id}",
		Summary:     "Consulta detalhes de uma transação específica",
		Tags:        []string{"Transações"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *GetTransactionInput) (*GetTransactionOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		tx, err := s.db.GetTransactionByID(ctx, sqlc.GetTransactionByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Transação não encontrada")
		}

		resp := &GetTransactionOutput{}
		resp.Body.Transaction = tx
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteTransaction",
		Method:      http.MethodDelete,
		Path:        "/v1/transactions/{id}",
		Summary:     "Exclui uma transação e estorna o saldo correspondente",
		Tags:        []string{"Transações"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *DeleteTransactionInput) (*struct{}, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para excluir transações")
		}

		tx, err := s.db.GetTransactionByID(ctx, sqlc.GetTransactionByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Transação não encontrada")
		}

		// Se concluída e não for cartão de crédito, estorna saldo
		if tx.Status == "completed" {
			acc, err := s.db.GetAccountByID(ctx, sqlc.GetAccountByIDParams{
				ID:       tx.AccountID,
				FamilyID: *uCtx.FamilyID,
			})
			if err == nil && acc.Kind != "credit_card" {
				delta := tx.AmountCents // se era despesa, soma de volta
				if tx.Kind == "income" {
					delta = -tx.AmountCents // se era receita, subtrai de volta
				}
				_, _ = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
					ID:                  tx.AccountID,
					FamilyID:            *uCtx.FamilyID,
					CurrentBalanceCents: delta,
				})
			}
		}

		err = s.db.DeleteTransaction(ctx, sqlc.DeleteTransactionParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao excluir transação")
		}

		return &struct{}{}, nil
	})
}

func ptrInt16(v int16) *int16 {
	return &v
}
