package domain

import (
	"time"

	"github.com/google/uuid"
)

type AccountKind string

const (
	AccountKindChecking   AccountKind = "checking"
	AccountKindSavings    AccountKind = "savings"
	AccountKindInvestment AccountKind = "investment"
	AccountKindCash       AccountKind = "cash"
	AccountKindCreditCard AccountKind = "credit_card"
)

type Account struct {
	ID                  uuid.UUID
	FamilyID            uuid.UUID
	OwnerUserID         uuid.UUID
	Name                string
	Kind                AccountKind
	Visibility          string
	Currency            string
	InitialBalanceCents int64
	CurrentBalanceCents int64
	Color               *string
	IsArchived          bool
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

type TransactionKind string

const (
	TransactionKindIncome   TransactionKind = "income"
	TransactionKindExpense  TransactionKind = "expense"
	TransactionKindTransfer TransactionKind = "transfer"
)

type Transaction struct {
	ID                   uuid.UUID
	FamilyID             uuid.UUID
	AccountID            uuid.UUID
	CategoryID           *uuid.UUID
	CreatedByUserID      uuid.UUID
	TargetUserID         *uuid.UUID
	Kind                 TransactionKind
	AmountCents          int64
	Description          string
	TransactedAt         time.Time
	Status               string
	CreditCardInvoiceID  *uuid.UUID
	InstallmentNumber    *int16
	InstallmentTotal     *int16
	InstallmentGroupID   *uuid.UUID
	Tags                 []string
	Notes                *string
	CategoryName         *string
	CategorySlug         *string
	CategoryIcon         *string
	CategoryColor        *string
	AccountName          *string
	CreatedAt            time.Time
	UpdatedAt            time.Time
}

type NetWorthSummary struct {
	TotalNetWorthCents int64     `json:"total_net_worth_cents"`
	CheckingCents      int64     `json:"checking_cents"`
	SavingsCents       int64     `json:"savings_cents"`
	InvestmentCents    int64     `json:"investment_cents"`
	CashCents          int64     `json:"cash_cents"`
	Accounts           []Account `json:"accounts"`
}
