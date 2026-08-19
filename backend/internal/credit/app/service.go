package app

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/credit/domain"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CreditService struct {
	queries *sqlc.Queries
	pool    *pgxpool.Pool
}

func NewCreditService(queries *sqlc.Queries, pool *pgxpool.Pool) *CreditService {
	return &CreditService{
		queries: queries,
		pool:    pool,
	}
}

func (s *CreditService) ListCreditCards(ctx context.Context, familyID uuid.UUID) ([]domain.CreditCard, error) {
	raw, err := s.queries.ListCreditCardsByFamilyID(ctx, familyID)
	if err != nil {
		return nil, err
	}

	out := make([]domain.CreditCard, len(raw))
	for i, c := range raw {
		out[i] = domain.CreditCard{
			ID:               c.ID,
			AccountID:        c.AccountID,
			FamilyID:         c.FamilyID,
			Name:             c.Name,
			LastFourDigits:   c.LastFourDigits,
			CreditLimitCents: c.CreditLimitCents,
			ClosingDay:       c.ClosingDay,
			DueDay:           c.DueDay,
			Color:            c.Color,
			AccountName:      c.AccountName,
			CreatedAt:        c.CreatedAt,
			UpdatedAt:        c.UpdatedAt,
		}
	}
	return out, nil
}

func (s *CreditService) GetCardProjections(ctx context.Context, familyID uuid.UUID, cardID *uuid.UUID, monthsAhead int) ([]domain.CardProjectionSummary, error) {
	if monthsAhead <= 0 {
		monthsAhead = 12
	}

	cards, err := s.ListCreditCards(ctx, familyID)
	if err != nil {
		return nil, err
	}

	var results []domain.CardProjectionSummary

	now := time.Now()
	currentYear := int16(now.Year())
	currentMonth := int16(now.Month())

	for _, card := range cards {
		if cardID != nil && *cardID != card.ID {
			continue
		}

		installments, err := s.queries.ListFutureInstallmentsByCardID(ctx, sqlc.ListFutureInstallmentsByCardIDParams{
			ID:          card.ID,
			FamilyID:    familyID,
			PeriodYear:  currentYear,
			PeriodMonth: currentMonth,
		})
		if err != nil {
			return nil, err
		}

		// Agrupa parcelas por ano/mês
		type monthKey struct {
			Year  int16
			Month int16
		}
		type monthData struct {
			TotalAmountCents int64
			Count            int
			DueDate          time.Time
		}

		monthlyMap := make(map[monthKey]*monthData)
		var usedLimit int64

		for _, inst := range installments {
			key := monthKey{Year: inst.PeriodYear, Month: inst.PeriodMonth}
			if _, exists := monthlyMap[key]; !exists {
				monthlyMap[key] = &monthData{DueDate: inst.DueDate}
			}
			monthlyMap[key].TotalAmountCents += inst.AmountCents
			monthlyMap[key].Count++
			usedLimit += inst.AmountCents
		}

		var projections []domain.CardMonthlyProjection
		for i := 0; i < monthsAhead; i++ {
			calcDate := now.AddDate(0, i, 0)
			y := int16(calcDate.Year())
			m := int16(calcDate.Month())
			key := monthKey{Year: y, Month: m}

			var totalCents int64
			var count int
			dueDate := time.Date(int(y), time.Month(m), int(card.DueDay), 0, 0, 0, 0, time.UTC)

			if data, ok := monthlyMap[key]; ok {
				totalCents = data.TotalAmountCents
				count = data.Count
				if !data.DueDate.IsZero() {
					dueDate = data.DueDate
				}
			}

			projections = append(projections, domain.CardMonthlyProjection{
				PeriodYear:        y,
				PeriodMonth:       m,
				MonthLabel:        formatMonthPTBR(m, y),
				DueDate:           dueDate,
				TotalAmountCents:  totalCents,
				InstallmentsCount: count,
			})
		}

		avail := card.CreditLimitCents - usedLimit
		if avail < 0 {
			avail = 0
		}

		results = append(results, domain.CardProjectionSummary{
			CardID:              card.ID,
			CardName:            card.Name,
			CreditLimitCents:    card.CreditLimitCents,
			UsedLimitCents:      usedLimit,
			AvailableLimitCents: avail,
			Projections:         projections,
		})
	}

	return results, nil
}

func formatMonthPTBR(m int16, y int16) string {
	meses := []string{"", "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"}
	if m >= 1 && m <= 12 {
		return fmt.Sprintf("%s/%02d", meses[m], y%100)
	}
	return fmt.Sprintf("%02d/%d", m, y)
}
