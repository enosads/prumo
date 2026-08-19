package money

import (
	"errors"
	"fmt"
)

// Currency is an ISO 4217 code (e.g. "BRL", "USD", "EUR").
type Currency string

const (
	BRL Currency = "BRL"
	USD Currency = "USD"
	EUR Currency = "EUR"
)

// Money represents a monetary amount stored in cents with scale.
type Money struct {
	Cents    int64
	Scale    uint8
	Currency Currency
}

var ErrCurrencyMismatch = errors.New("money: currency mismatch")

// New constructs a Money value from integer cents.
func New(cents int64, scale uint8, currency Currency) Money {
	return Money{Cents: cents, Scale: scale, Currency: currency}
}

// BRLFromCents constructs a BRL Money value from cents with scale 2.
func BRLFromCents(cents int64) Money {
	return Money{Cents: cents, Scale: 2, Currency: BRL}
}

// Add returns m + other.
func (m Money) Add(other Money) (Money, error) {
	if m.Currency != other.Currency {
		return Money{}, ErrCurrencyMismatch
	}
	m, other = alignScale(m, other)
	return Money{Cents: m.Cents + other.Cents, Scale: m.Scale, Currency: m.Currency}, nil
}

// Sub returns m - other.
func (m Money) Sub(other Money) (Money, error) {
	if m.Currency != other.Currency {
		return Money{}, ErrCurrencyMismatch
	}
	m, other = alignScale(m, other)
	return Money{Cents: m.Cents - other.Cents, Scale: m.Scale, Currency: m.Currency}, nil
}

// Neg returns the negated amount.
func (m Money) Neg() Money {
	return Money{Cents: -m.Cents, Scale: m.Scale, Currency: m.Currency}
}

// IsZero reports whether amount is 0.
func (m Money) IsZero() bool {
	return m.Cents == 0
}

// IsNeg reports whether amount is negative.
func (m Money) IsNeg() bool {
	return m.Cents < 0
}

// Equal reports whether two Money values are equal.
func (m Money) Equal(other Money) bool {
	if m.Currency != other.Currency {
		return false
	}
	m, other = alignScale(m, other)
	return m.Cents == other.Cents
}

// String returns formatted currency (e.g. "BRL 12.34").
func (m Money) String() string {
	divisor := int64(1)
	for i := uint8(0); i < m.Scale; i++ {
		divisor *= 10
	}
	abs := m.Cents
	sign := ""
	if abs < 0 {
		abs = -abs
		sign = "-"
	}
	return fmt.Sprintf("%s %s%d.%0*d", m.Currency, sign, abs/divisor, m.Scale, abs%divisor)
}

// FormatPTBR returns formatted currency for pt-BR display (e.g. "R$ 1.234,56").
func (m Money) FormatPTBR() string {
	abs := m.Cents
	sign := ""
	if abs < 0 {
		abs = -abs
		sign = "-"
	}
	reais := abs / 100
	centavos := abs % 100
	return fmt.Sprintf("%sR$ %d,%02d", sign, reais, centavos)
}

func alignScale(a, b Money) (Money, Money) {
	if a.Scale == b.Scale {
		return a, b
	}
	if a.Scale < b.Scale {
		diff := b.Scale - a.Scale
		factor := pow10(diff)
		a.Cents *= factor
		a.Scale = b.Scale
	} else {
		diff := a.Scale - b.Scale
		factor := pow10(diff)
		b.Cents *= factor
		b.Scale = a.Scale
	}
	return a, b
}

func pow10(n uint8) int64 {
	r := int64(1)
	for i := uint8(0); i < n; i++ {
		r *= 10
	}
	return r
}
