package api

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreateCreditCardInput struct {
	Body struct {
		AccountID        *uuid.UUID `json:"account_id,omitempty" doc:"ID da conta associada (se omitido, será criada uma conta de cartão automaticamente)"`
		Name             string     `json:"name" minLength:"2" doc:"Nome do cartão (ex: Nubank Ultravioleta, XP Visa Infinite)"`
		LastFourDigits   *string    `json:"last_four_digits,omitempty" maxLength:"4" doc:"Últimos 4 dígitos"`
		CreditLimitCents int64      `json:"credit_limit_cents" minimum:"100" doc:"Limite de crédito em centavos"`
		ClosingDay       int        `json:"closing_day" minimum:"1" maximum:"31" doc:"Dia do mês de fechamento da fatura"`
		DueDay           int        `json:"due_day" minimum:"1" maximum:"31" doc:"Dia do mês de vencimento da fatura"`
		Color            *string    `json:"color,omitempty" doc:"Cor do cartão para UI (ex: #820AD1)"`
	}
}

type CreditCardSummary struct {
	Card                sqlc.CreditCard         `json:"card"`
	AccountName         string                  `json:"account_name"`
	CurrentInvoice      *sqlc.CreditCardInvoice `json:"current_invoice,omitempty"`
	UsedLimitCents      int64                   `json:"used_limit_cents"`
	AvailableLimitCents int64                   `json:"available_limit_cents"`
}

type CreateCreditCardOutput struct {
	Body struct {
		Card CreditCardSummary `json:"card"`
	}
}

type ListCreditCardsOutput struct {
	Body struct {
		Cards []CreditCardSummary `json:"cards"`
	}
}

type GetCreditCardInput struct {
	ID uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
}

type GetCreditCardOutput struct {
	Body struct {
		Card CreditCardSummary `json:"card"`
	}
}

type ListCardInvoicesInput struct {
	ID uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
}

type ListCardInvoicesOutput struct {
	Body struct {
		Invoices []sqlc.CreditCardInvoice `json:"invoices"`
	}
}

type GetInvoiceDetailsInput struct {
	CardID    uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
	InvoiceID uuid.UUID `path:"invoiceId" doc:"ID da fatura"`
}

type GetInvoiceDetailsOutput struct {
	Body struct {
		Invoice      sqlc.CreditCardInvoice                   `json:"invoice"`
		Transactions []sqlc.ListTransactionsByInvoiceIDRow   `json:"transactions"`
	}
}

type PayInvoiceInput struct {
	CardID    uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
	InvoiceID uuid.UUID `path:"invoiceId" doc:"ID da fatura"`
	Body      struct {
		PaymentAccountID uuid.UUID `json:"payment_account_id" doc:"Conta corrente para débito do pagamento"`
		AmountCents      int64     `json:"amount_cents" minimum:"1" doc:"Valor a pagar em centavos"`
	}
}

type PayInvoiceOutput struct {
	Body struct {
		Invoice     sqlc.CreditCardInvoice `json:"invoice"`
		Transaction sqlc.Transaction       `json:"payment_transaction"`
	}
}

type GetInstallmentsProjectionInput struct {
	ID uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
}

type MemberSpendingShare struct {
	UserName    string `json:"user_name"`
	AmountCents int64  `json:"amount_cents"`
}

type MonthlyProjectionItem struct {
	PeriodYear        int16                  `json:"period_year"`
	PeriodMonth       int16                  `json:"period_month"`
	MonthLabel        string                 `json:"month_label"`
	DueDate           time.Time              `json:"due_date"`
	TotalAmountCents  int64                  `json:"total_amount_cents"`
	InstallmentsCount int                    `json:"installments_count"`
	MemberShares      []MemberSpendingShare  `json:"member_shares"`
	Transactions      []sqlc.ListFutureInstallmentsByCardIDRow `json:"transactions"`
}

type GetInstallmentsProjectionOutput struct {
	Body struct {
		Projections []MonthlyProjectionItem `json:"projections"`
	}
}

type SimulateAnticipationInput struct {
	ID   uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
	Body struct {
		TransactionIDs     []uuid.UUID `json:"transaction_ids" doc:"IDs das parcelas futuras a antecipar"`
		AnnualDiscountRate *float64    `json:"annual_discount_rate,omitempty" doc:"Taxa anual de desconto em porcentagem (padrão: 10.0)"`
	}
}

type AnticipatedItemDetail struct {
	TransactionID   uuid.UUID `json:"transaction_id"`
	Description     string    `json:"description"`
	OriginalAmount  int64     `json:"original_amount_cents"`
	DiscountCents   int64     `json:"discount_cents"`
	NetCalculated   int64     `json:"net_amount_cents"`
	InstallmentInfo string    `json:"installment_info"`
	MonthsAhead     int       `json:"months_ahead"`
}

type SimulateAnticipationOutput struct {
	Body struct {
		OriginalTotalCents    int64                   `json:"original_total_cents"`
		TotalDiscountCents    int64                   `json:"total_discount_cents"`
		AnticipatedTotalCents int64                   `json:"anticipated_total_cents"`
		Items                 []AnticipatedItemDetail `json:"items"`
	}
}

type ApplyAnticipationInput struct {
	ID   uuid.UUID `path:"id" doc:"ID do cartão de crédito"`
	Body struct {
		TransactionIDs     []uuid.UUID `json:"transaction_ids" doc:"IDs das parcelas futuras a antecipar"`
		AnnualDiscountRate *float64    `json:"annual_discount_rate,omitempty" doc:"Taxa anual de desconto"`
	}
}

type ApplyAnticipationOutput struct {
	Body struct {
		TargetInvoice      sqlc.CreditCardInvoice `json:"target_invoice"`
		DiscountCents      int64                  `json:"discount_cents"`
		NetTotalAddedCents int64                  `json:"net_total_added_cents"`
		UpdatedCount       int                    `json:"updated_count"`
	}
}

func (s *Server) registerCardRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "createCreditCard",
		Method:      http.MethodPost,
		Path:        "/v1/cards",
		Summary:     "Cadastra um novo cartão de crédito",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *CreateCreditCardInput) (*CreateCreditCardOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para cadastrar cartões")
		}

		var accountID uuid.UUID
		var accountName string

		if input.Body.AccountID != nil && *input.Body.AccountID != uuid.Nil {
			acc, err := s.db.GetAccountByID(ctx, sqlc.GetAccountByIDParams{
				ID:       *input.Body.AccountID,
				FamilyID: *uCtx.FamilyID,
			})
			if err != nil {
				return nil, httpErrorNotFound("Conta não encontrada")
			}
			accountID = acc.ID
			accountName = acc.Name
		} else {
			// Cria conta financeira correspondente com kind = credit_card
			acc, err := s.db.CreateAccount(ctx, sqlc.CreateAccountParams{
				FamilyID:            *uCtx.FamilyID,
				OwnerUserID:         uCtx.UserID,
				Name:                input.Body.Name,
				Kind:                "credit_card",
				Visibility:          "shared",
				Currency:            "BRL",
				InitialBalanceCents: 0,
				CurrentBalanceCents: 0,
				Color:               input.Body.Color,
			})
			if err != nil {
				return nil, httpErrorInternal("Erro ao criar conta de cartão de crédito")
			}
			accountID = acc.ID
			accountName = acc.Name
		}

		card, err := s.db.CreateCreditCard(ctx, sqlc.CreateCreditCardParams{
			AccountID:        accountID,
			FamilyID:         *uCtx.FamilyID,
			Name:             input.Body.Name,
			LastFourDigits:   input.Body.LastFourDigits,
			CreditLimitCents: input.Body.CreditLimitCents,
			ClosingDay:       int16(input.Body.ClosingDay),
			DueDay:           int16(input.Body.DueDay),
			Color:            input.Body.Color,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar cartão de crédito")
		}

		// Cria fatura inicial aberta para o mês atual
		now := time.Now()
		closingDate := calculateInvoiceDate(now.Year(), int(now.Month()), input.Body.ClosingDay)
		dueDate := calculateInvoiceDate(now.Year(), int(now.Month()), input.Body.DueDay)
		if input.Body.DueDay < input.Body.ClosingDay {
			dueDate = dueDate.AddDate(0, 1, 0)
		}

		inv, _ := s.db.CreateCreditCardInvoice(ctx, sqlc.CreateCreditCardInvoiceParams{
			CreditCardID:     card.ID,
			FamilyID:         *uCtx.FamilyID,
			PeriodYear:       int16(now.Year()),
			PeriodMonth:      int16(now.Month()),
			ClosingDate:      closingDate,
			DueDate:          dueDate,
			TotalAmountCents: 0,
			Status:           "open",
		})

		resp := &CreateCreditCardOutput{}
		resp.Body.Card = CreditCardSummary{
			Card:                card,
			AccountName:         accountName,
			CurrentInvoice:      &inv,
			UsedLimitCents:      0,
			AvailableLimitCents: card.CreditLimitCents,
		}
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listCreditCards",
		Method:      http.MethodGet,
		Path:        "/v1/cards",
		Summary:     "Lista todos os cartões de crédito da família",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*ListCreditCardsOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		cards, err := s.db.ListCreditCardsByFamilyID(ctx, *uCtx.FamilyID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar cartões")
		}

		now := time.Now()
		var summaries []CreditCardSummary

		for _, c := range cards {
			inv, err := s.db.GetCreditCardInvoiceByPeriod(ctx, sqlc.GetCreditCardInvoiceByPeriodParams{
				CreditCardID: c.ID,
				PeriodYear:   int16(now.Year()),
				PeriodMonth:  int16(now.Month()),
			})

			var curInv *sqlc.CreditCardInvoice
			var usedCents int64
			if err == nil {
				curInv = &inv
				usedCents = inv.TotalAmountCents - inv.PaidAmountCents
				if usedCents < 0 {
					usedCents = 0
				}
			}

			avail := c.CreditLimitCents - usedCents
			if avail < 0 {
				avail = 0
			}

			summaries = append(summaries, CreditCardSummary{
				Card: sqlc.CreditCard{
					ID:               c.ID,
					AccountID:        c.AccountID,
					FamilyID:         c.FamilyID,
					Name:             c.Name,
					LastFourDigits:   c.LastFourDigits,
					CreditLimitCents: c.CreditLimitCents,
					ClosingDay:       c.ClosingDay,
					DueDay:           c.DueDay,
					Color:            c.Color,
					CreatedAt:        c.CreatedAt,
					UpdatedAt:        c.UpdatedAt,
				},
				AccountName:         c.AccountName,
				CurrentInvoice:      curInv,
				UsedLimitCents:      usedCents,
				AvailableLimitCents: avail,
			})
		}

		resp := &ListCreditCardsOutput{}
		resp.Body.Cards = summaries
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getCreditCard",
		Method:      http.MethodGet,
		Path:        "/v1/cards/{id}",
		Summary:     "Consulta os dados e limites de um cartão",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *GetCreditCardInput) (*GetCreditCardOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		card, err := s.db.GetCreditCardByID(ctx, sqlc.GetCreditCardByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Cartão de crédito não encontrado")
		}

		now := time.Now()
		inv, _ := s.db.GetCreditCardInvoiceByPeriod(ctx, sqlc.GetCreditCardInvoiceByPeriodParams{
			CreditCardID: card.ID,
			PeriodYear:   int16(now.Year()),
			PeriodMonth:  int16(now.Month()),
		})

		used := inv.TotalAmountCents - inv.PaidAmountCents
		if used < 0 {
			used = 0
		}
		avail := card.CreditLimitCents - used
		if avail < 0 {
			avail = 0
		}

		resp := &GetCreditCardOutput{}
		resp.Body.Card = CreditCardSummary{
			Card:                card,
			CurrentInvoice:      &inv,
			UsedLimitCents:      used,
			AvailableLimitCents: avail,
		}
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listCardInvoices",
		Method:      http.MethodGet,
		Path:        "/v1/cards/{id}/invoices",
		Summary:     "Lista as faturas do cartão de crédito",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *ListCardInvoicesInput) (*ListCardInvoicesOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		_, err = s.db.GetCreditCardByID(ctx, sqlc.GetCreditCardByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Cartão de crédito não encontrado")
		}

		invoices, err := s.db.ListCreditCardInvoicesByCardID(ctx, input.ID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar faturas")
		}

		resp := &ListCardInvoicesOutput{}
		resp.Body.Invoices = invoices
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getInvoiceDetails",
		Method:      http.MethodGet,
		Path:        "/v1/cards/{id}/invoices/{invoiceId}",
		Summary:     "Detalha os lançamentos e valores de uma fatura específica",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *GetInvoiceDetailsInput) (*GetInvoiceDetailsOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		invoice, err := s.db.GetCreditCardInvoiceByID(ctx, sqlc.GetCreditCardInvoiceByIDParams{
			ID:       input.InvoiceID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Fatura não encontrada")
		}

		txs, err := s.db.ListTransactionsByInvoiceID(ctx, sqlc.ListTransactionsByInvoiceIDParams{
			CreditCardInvoiceID: &invoice.ID,
			FamilyID:            *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao buscar transações da fatura")
		}

		resp := &GetInvoiceDetailsOutput{}
		resp.Body.Invoice = invoice
		resp.Body.Transactions = txs
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "payInvoice",
		Method:      http.MethodPost,
		Path:        "/v1/cards/{id}/invoices/{invoiceId}/pay",
		Summary:     "Efetua o pagamento total ou parcial de uma fatura com débito em conta",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *PayInvoiceInput) (*PayInvoiceOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para pagar faturas")
		}

		invoice, err := s.db.GetCreditCardInvoiceByID(ctx, sqlc.GetCreditCardInvoiceByIDParams{
			ID:       input.InvoiceID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Fatura não encontrada")
		}

		paymentAcc, err := s.db.GetAccountByID(ctx, sqlc.GetAccountByIDParams{
			ID:       input.Body.PaymentAccountID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Conta de pagamento não encontrada")
		}

		// Debita da conta corrente
		_, err = s.db.UpdateAccountBalance(ctx, sqlc.UpdateAccountBalanceParams{
			ID:                  paymentAcc.ID,
			FamilyID:            *uCtx.FamilyID,
			CurrentBalanceCents: -input.Body.AmountCents,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao debitar conta de pagamento")
		}

		// Registra transação de pagamento
		tx, err := s.db.CreateTransaction(ctx, sqlc.CreateTransactionParams{
			FamilyID:            *uCtx.FamilyID,
			AccountID:           paymentAcc.ID,
			CategoryID:          nil,
			CreatedByUserID:     uCtx.UserID,
			TargetUserID:        nil,
			Kind:                "expense",
			AmountCents:         input.Body.AmountCents,
			Description:         fmt.Sprintf("Pagamento Fatura (%02d/%d)", invoice.PeriodMonth, invoice.PeriodYear),
			TransactedAt:        time.Now(),
			Status:              "completed",
			CreditCardInvoiceID: nil,
			InstallmentNumber:   ptrInt16(1),
			InstallmentTotal:    ptrInt16(1),
			InstallmentGroupID:  nil,
			Tags:                []string{"fatura", "pagamento"},
			Notes:               nil,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao registrar lançamento de pagamento")
		}

		newStatus := "partially_paid"
		if invoice.PaidAmountCents+input.Body.AmountCents >= invoice.TotalAmountCents {
			newStatus = "paid"
		}

		updatedInv, err := s.db.UpdateCreditCardInvoicePaid(ctx, sqlc.UpdateCreditCardInvoicePaidParams{
			ID:                invoice.ID,
			FamilyID:          *uCtx.FamilyID,
			PaidAmountCents:   input.Body.AmountCents,
			Status:            newStatus,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao atualizar status da fatura")
		}

		resp := &PayInvoiceOutput{}
		resp.Body.Invoice = updatedInv
		resp.Body.Transaction = tx
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getInstallmentsProjection",
		Method:      http.MethodGet,
		Path:        "/v1/cards/{id}/installments",
		Summary:     "Projeta as faturas e parcelas futuras dos próximos 12 meses",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *GetInstallmentsProjectionInput) (*GetInstallmentsProjectionOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		now := time.Now()
		futureTxs, err := s.db.ListFutureInstallmentsByCardID(ctx, sqlc.ListFutureInstallmentsByCardIDParams{
			ID:          input.ID,
			FamilyID:    *uCtx.FamilyID,
			PeriodYear:  int16(now.Year()),
			PeriodMonth: int16(now.Month()),
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao consultar projeção de parcelas")
		}

		// Agrupa por (ano, mês)
		type monthKey struct {
			Year  int16
			Month int16
		}

		grouped := make(map[monthKey][]sqlc.ListFutureInstallmentsByCardIDRow)
		for _, tx := range futureTxs {
			k := monthKey{Year: tx.PeriodYear, Month: tx.PeriodMonth}
			grouped[k] = append(grouped[k], tx)
		}

		monthNames := []string{
			"", "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez",
		}

		var projections []MonthlyProjectionItem
		for m := 0; m < 12; m++ {
			targetDate := now.AddDate(0, m, 0)
			y := int16(targetDate.Year())
			mon := int16(targetDate.Month())

			items := grouped[monthKey{Year: y, Month: mon}]
			var totalCents int64
			memberTotals := make(map[string]int64)

			for _, it := range items {
				totalCents += it.AmountCents
				authorName := it.AuthorName
				if it.TargetName != nil && *it.TargetName != "" {
					authorName = *it.TargetName
				}
				memberTotals[authorName] += it.AmountCents
			}

			var shares []MemberSpendingShare
			for name, amt := range memberTotals {
				shares = append(shares, MemberSpendingShare{UserName: name, AmountCents: amt})
			}

			projections = append(projections, MonthlyProjectionItem{
				PeriodYear:        y,
				PeriodMonth:       mon,
				MonthLabel:        fmt.Sprintf("%s %d", monthNames[mon], y),
				DueDate:           targetDate,
				TotalAmountCents:  totalCents,
				InstallmentsCount: len(items),
				MemberShares:      shares,
				Transactions:      items,
			})
		}

		resp := &GetInstallmentsProjectionOutput{}
		resp.Body.Projections = projections
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "simulateAnticipation",
		Method:      http.MethodPost,
		Path:        "/v1/cards/{id}/installments/anticipate/simulate",
		Summary:     "Simula o desconto financeiro na antecipação de parcelas futuras",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *SimulateAnticipationInput) (*SimulateAnticipationOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		rate := 10.0 // 10% ao ano padrão
		if input.Body.AnnualDiscountRate != nil && *input.Body.AnnualDiscountRate > 0 {
			rate = *input.Body.AnnualDiscountRate
		}
		monthlyRate := math.Pow(1.0+(rate/100.0), 1.0/12.0) - 1.0

		now := time.Now()
		currentMonths := now.Year()*12 + int(now.Month())

		var details []AnticipatedItemDetail
		var originalTotal, discountTotal int64

		for _, txID := range input.Body.TransactionIDs {
			tx, err := s.db.GetTransactionByID(ctx, sqlc.GetTransactionByIDParams{
				ID:       txID,
				FamilyID: *uCtx.FamilyID,
			})
			if err != nil {
				continue
			}

			txMonths := tx.TransactedAt.Year()*12 + int(tx.TransactedAt.Month())
			monthsAhead := txMonths - currentMonths
			if monthsAhead < 1 {
				monthsAhead = 1
			}

			// PV = FV / (1 + i)^n
			fv := float64(tx.AmountCents)
			pv := fv / math.Pow(1.0+monthlyRate, float64(monthsAhead))
			disc := int64(math.Round(fv - pv))
			net := tx.AmountCents - disc

			instInfo := "1/1"
			if tx.InstallmentNumber != nil && tx.InstallmentTotal != nil {
				instInfo = fmt.Sprintf("%d/%d", *tx.InstallmentNumber, *tx.InstallmentTotal)
			}

			details = append(details, AnticipatedItemDetail{
				TransactionID:   tx.ID,
				Description:     tx.Description,
				OriginalAmount:  tx.AmountCents,
				DiscountCents:   disc,
				NetCalculated:   net,
				InstallmentInfo: instInfo,
				MonthsAhead:     monthsAhead,
			})

			originalTotal += tx.AmountCents
			discountTotal += disc
		}

		resp := &SimulateAnticipationOutput{}
		resp.Body.OriginalTotalCents = originalTotal
		resp.Body.TotalDiscountCents = discountTotal
		resp.Body.AnticipatedTotalCents = originalTotal - discountTotal
		resp.Body.Items = details
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "applyAnticipation",
		Method:      http.MethodPost,
		Path:        "/v1/cards/{id}/installments/anticipate/apply",
		Summary:     "Efetiva a antecipação de parcelas com desconto para a fatura atual",
		Tags:        []string{"Cartões"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *ApplyAnticipationInput) (*ApplyAnticipationOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		if uCtx.Role == nil || !authz.CanWriteFinancials(*uCtx.Role) {
			return nil, httpErrorForbidden("Permissão insuficiente para antecipar parcelas")
		}

		card, err := s.db.GetCreditCardByID(ctx, sqlc.GetCreditCardByIDParams{
			ID:       input.ID,
			FamilyID: *uCtx.FamilyID,
		})
		if err != nil {
			return nil, httpErrorNotFound("Cartão de crédito não encontrado")
		}

		// Garante fatura aberta no mês atual
		now := time.Now()
		currentInv, err := s.db.GetCreditCardInvoiceByPeriod(ctx, sqlc.GetCreditCardInvoiceByPeriodParams{
			CreditCardID: card.ID,
			PeriodYear:   int16(now.Year()),
			PeriodMonth:  int16(now.Month()),
		})
		if err != nil {
			closingDate := calculateInvoiceDate(now.Year(), int(now.Month()), int(card.ClosingDay))
			dueDate := calculateInvoiceDate(now.Year(), int(now.Month()), int(card.DueDay))
			currentInv, err = s.db.CreateCreditCardInvoice(ctx, sqlc.CreateCreditCardInvoiceParams{
				CreditCardID:     card.ID,
				FamilyID:         *uCtx.FamilyID,
				PeriodYear:       int16(now.Year()),
				PeriodMonth:      int16(now.Month()),
				ClosingDate:      closingDate,
				DueDate:          dueDate,
				TotalAmountCents: 0,
				Status:           "open",
			})
			if err != nil {
				return nil, httpErrorInternal("Erro ao obter fatura atual")
			}
		}

		rate := 10.0
		if input.Body.AnnualDiscountRate != nil && *input.Body.AnnualDiscountRate > 0 {
			rate = *input.Body.AnnualDiscountRate
		}
		monthlyRate := math.Pow(1.0+(rate/100.0), 1.0/12.0) - 1.0
		currentMonths := now.Year()*12 + int(now.Month())

		var totalDiscount, totalNetAdded int64
		var count int

		for _, txID := range input.Body.TransactionIDs {
			tx, err := s.db.GetTransactionByID(ctx, sqlc.GetTransactionByIDParams{
				ID:       txID,
				FamilyID: *uCtx.FamilyID,
			})
			if err != nil {
				continue
			}

			txMonths := tx.TransactedAt.Year()*12 + int(tx.TransactedAt.Month())
			monthsAhead := txMonths - currentMonths
			if monthsAhead < 1 {
				monthsAhead = 1
			}

			fv := float64(tx.AmountCents)
			pv := fv / math.Pow(1.0+monthlyRate, float64(monthsAhead))
			disc := int64(math.Round(fv - pv))
			net := tx.AmountCents - disc

			note := fmt.Sprintf("Antecipada com desconto de %s", formatCents(disc))
			_, err = s.db.UpdateTransactionInvoiceAndAmount(ctx, sqlc.UpdateTransactionInvoiceAndAmountParams{
				ID:                  tx.ID,
				FamilyID:            *uCtx.FamilyID,
				CreditCardInvoiceID: &currentInv.ID,
				AmountCents:         net,
				Notes:               &note,
			})
			if err == nil {
				totalDiscount += disc
				totalNetAdded += net
				count++
			}
		}

		// Atualiza o total da fatura aberta
		updatedInv, err := s.db.UpdateCreditCardInvoiceTotals(ctx, sqlc.UpdateCreditCardInvoiceTotalsParams{
			ID:               currentInv.ID,
			FamilyID:         *uCtx.FamilyID,
			TotalAmountCents: currentInv.TotalAmountCents + totalNetAdded,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao atualizar total da fatura")
		}

		resp := &ApplyAnticipationOutput{}
		resp.Body.TargetInvoice = updatedInv
		resp.Body.DiscountCents = totalDiscount
		resp.Body.NetTotalAddedCents = totalNetAdded
		resp.Body.UpdatedCount = count
		return resp, nil
	})
}

func calculateInvoiceDate(year int, month int, day int) time.Time {
	if day > 28 {
		// Ajusta para meses com menos dias
		if month == 2 {
			day = 28
		} else if day == 31 && (month == 4 || month == 6 || month == 9 || month == 11) {
			day = 30
		}
	}
	return time.Date(year, time.Month(month), day, 12, 0, 0, 0, time.UTC)
}

func formatCents(cents int64) string {
	return fmt.Sprintf("R$ %.2f", float64(cents)/100.0)
}
