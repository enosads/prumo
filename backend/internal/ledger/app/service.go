package app

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/db/sqlc"
	"github.com/enosads/prumo/backend/internal/ledger/domain"
)

type LedgerService struct {
	queries *sqlc.Queries
	pool    *pgxpool.Pool
}

func NewLedgerService(queries *sqlc.Queries, pool *pgxpool.Pool) *LedgerService {
	return &LedgerService{
		queries: queries,
		pool:    pool,
	}
}

func (s *LedgerService) EnsureSeedCategories(ctx context.Context, familyID uuid.UUID) error {
	count, err := s.queries.CountCategoriesByFamilyID(ctx, familyID)
	if err != nil {
		return err
	}

	if count == 0 {
		for _, root := range domain.CanonicalRootCategories {
			slug := root.Slug
			icon := root.Icon
			color := root.Color
			_, err := s.queries.CreateCategory(ctx, sqlc.CreateCategoryParams{
				FamilyID:   familyID,
				Name:       root.NamePTBR,
				Icon:       &icon,
				Color:      &color,
				Kind:       string(root.Kind),
				ParentID:   nil,
				Slug:       &slug,
				SystemOnly: root.SystemOnly,
			})
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (s *LedgerService) ListCategories(ctx context.Context, familyID uuid.UUID, includeSystem bool) ([]domain.Category, error) {
	if err := s.EnsureSeedCategories(ctx, familyID); err != nil {
		return nil, err
	}

	var raw []sqlc.Category
	var err error
	if includeSystem {
		raw, err = s.queries.ListCategoriesByFamilyID(ctx, familyID)
	} else {
		raw, err = s.queries.ListVisibleCategoriesByFamilyID(ctx, familyID)
	}
	if err != nil {
		return nil, err
	}

	out := make([]domain.Category, len(raw))
	for i, c := range raw {
		out[i] = domain.Category{
			ID:         c.ID,
			FamilyID:   c.FamilyID,
			Name:       c.Name,
			Slug:       c.Slug,
			Icon:       c.Icon,
			Color:      c.Color,
			Kind:       domain.CategoryKind(c.Kind),
			ParentID:   c.ParentID,
			SystemOnly: c.SystemOnly,
			CreatedAt:  c.CreatedAt,
		}
	}
	return out, nil
}

func (s *LedgerService) GetCategoryBySlug(ctx context.Context, familyID uuid.UUID, slug string) (*domain.Category, error) {
	c, err := s.queries.GetCategoryBySlug(ctx, sqlc.GetCategoryBySlugParams{
		FamilyID: familyID,
		Slug:     &slug,
	})
	if err != nil {
		return nil, err
	}
	return &domain.Category{
		ID:         c.ID,
		FamilyID:   c.FamilyID,
		Name:       c.Name,
		Slug:       c.Slug,
		Icon:       c.Icon,
		Color:      c.Color,
		Kind:       domain.CategoryKind(c.Kind),
		ParentID:   c.ParentID,
		SystemOnly: c.SystemOnly,
		CreatedAt:  c.CreatedAt,
	}, nil
}

func (s *LedgerService) GetConsolidatedNetWorth(ctx context.Context, familyID uuid.UUID) (*domain.NetWorthSummary, error) {
	accounts, err := s.queries.ListAccountsByFamilyID(ctx, familyID)
	if err != nil {
		return nil, err
	}

	summary := &domain.NetWorthSummary{
		Accounts: make([]domain.Account, len(accounts)),
	}

	for i, a := range accounts {
		summary.Accounts[i] = domain.Account{
			ID:                  a.ID,
			FamilyID:            a.FamilyID,
			OwnerUserID:         a.OwnerUserID,
			Name:                a.Name,
			Kind:                domain.AccountKind(a.Kind),
			Visibility:          a.Visibility,
			Currency:            a.Currency,
			InitialBalanceCents: a.InitialBalanceCents,
			CurrentBalanceCents: a.CurrentBalanceCents,
			Color:               a.Color,
			IsArchived:          a.IsArchived,
			CreatedAt:           a.CreatedAt,
			UpdatedAt:           a.UpdatedAt,
		}

		switch a.Kind {
		case "checking":
			summary.CheckingCents += a.CurrentBalanceCents
			summary.TotalNetWorthCents += a.CurrentBalanceCents
		case "savings":
			summary.SavingsCents += a.CurrentBalanceCents
			summary.TotalNetWorthCents += a.CurrentBalanceCents
		case "investment":
			summary.InvestmentCents += a.CurrentBalanceCents
			summary.TotalNetWorthCents += a.CurrentBalanceCents
		case "cash":
			summary.CashCents += a.CurrentBalanceCents
			summary.TotalNetWorthCents += a.CurrentBalanceCents
		case "credit_card":
			// Cartão de crédito subtrai do patrimônio líquido caso haja saldo devedor
			summary.TotalNetWorthCents -= a.CurrentBalanceCents
		}
	}

	return summary, nil
}

func (s *LedgerService) QueryCashFlow(ctx context.Context, filter domain.CashFlowFilter) (*domain.CashFlowSummary, error) {
	var catID *uuid.UUID = filter.CategoryID
	if catID == nil && filter.CategorySlug != nil && *filter.CategorySlug != "" {
		if cat, err := s.GetCategoryBySlug(ctx, filter.FamilyID, *filter.CategorySlug); err == nil && cat != nil {
			catID = &cat.ID
		}
	}

	limit := int32(filter.Limit)
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	offset := int32(filter.Offset)

	raw, err := s.queries.ListTransactionsByFamilyIDWithFilters(ctx, sqlc.ListTransactionsByFamilyIDWithFiltersParams{
		FamilyID:    filter.FamilyID,
		AccountID:   filter.AccountID,
		CategoryID:  catID,
		Kind:        filter.Kind,
		UserID:      filter.UserID,
		FromDate:    filter.FromDate,
		ToDate:      filter.ToDate,
		LimitCount:  limit,
		OffsetCount: offset,
	})
	if err != nil {
		return nil, err
	}

	summary := &domain.CashFlowSummary{
		Transactions: make([]domain.Transaction, len(raw)),
	}

	for i, t := range raw {
		summary.Transactions[i] = domain.Transaction{
			ID:                  t.ID,
			FamilyID:            t.FamilyID,
			AccountID:           t.AccountID,
			CategoryID:          t.CategoryID,
			CreatedByUserID:     t.CreatedByUserID,
			TargetUserID:        t.TargetUserID,
			Kind:                domain.TransactionKind(t.Kind),
			AmountCents:         t.AmountCents,
			Description:         t.Description,
			TransactedAt:        t.TransactedAt,
			Status:              t.Status,
			CreditCardInvoiceID: t.CreditCardInvoiceID,
			InstallmentNumber:   t.InstallmentNumber,
			InstallmentTotal:    t.InstallmentTotal,
			InstallmentGroupID:  t.InstallmentGroupID,
			Tags:                t.Tags,
			Notes:               t.Notes,
			CategoryName:        t.CategoryName,
			CategoryIcon:        t.CategoryIcon,
			CategoryColor:       t.CategoryColor,
			AccountName:         &t.AccountName,
			CreatedAt:           t.CreatedAt,
			UpdatedAt:           t.UpdatedAt,
		}

		if t.Kind == "income" {
			summary.TotalIncomeCents += t.AmountCents
		} else if t.Kind == "expense" {
			summary.TotalExpenseCents += t.AmountCents
		}
	}

	summary.NetCashFlowCents = summary.TotalIncomeCents - summary.TotalExpenseCents

	// Se não veio período delimitado, calcula totais do mês atual
	if filter.FromDate != nil && filter.ToDate != nil {
		totals, err := s.queries.GetMonthlyCashFlowTotals(ctx, sqlc.GetMonthlyCashFlowTotalsParams{
			FamilyID:  filter.FamilyID,
			StartDate: *filter.FromDate,
			EndDate:   *filter.ToDate,
		})
		if err == nil {
			summary.TotalIncomeCents = totals.TotalIncomeCents
			summary.TotalExpenseCents = totals.TotalExpenseCents
			summary.NetCashFlowCents = totals.TotalIncomeCents - totals.TotalExpenseCents
		}
	}

	return summary, nil
}
