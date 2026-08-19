package domain

import (
	"time"

	"github.com/google/uuid"
)

type CreditCard struct {
	ID               uuid.UUID
	AccountID        uuid.UUID
	FamilyID         uuid.UUID
	Name             string
	LastFourDigits   *string
	CreditLimitCents int64
	ClosingDay       int16
	DueDay           int16
	Color            *string
	AccountName      string
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

type CreditCardInvoice struct {
	ID               uuid.UUID
	CreditCardID     uuid.UUID
	FamilyID         uuid.UUID
	PeriodYear       int16
	PeriodMonth      int16
	ClosingDate      time.Time
	DueDate          time.Time
	TotalAmountCents int64
	PaidAmountCents  int64
	Status           string
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

type CardMonthlyProjection struct {
	PeriodYear         int16
	PeriodMonth        int16
	MonthLabel         string
	DueDate            time.Time
	TotalAmountCents   int64
	InstallmentsCount  int
}

type CardProjectionSummary struct {
	CardID            uuid.UUID
	CardName          string
	CreditLimitCents  int64
	UsedLimitCents    int64
	AvailableLimitCents int64
	Projections       []CardMonthlyProjection
}
