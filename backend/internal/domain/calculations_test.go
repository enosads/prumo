package domain

import (
	"math"
	"testing"
)

func TestInstallmentPartitioning(t *testing.T) {
	totalAmount := int64(100000) // R$ 1.000,00
	installments := 3

	baseAmount := totalAmount / int64(installments)
	remainder := totalAmount % int64(installments)

	var sum int64
	for i := 1; i <= installments; i++ {
		amount := baseAmount
		if i == 1 {
			amount += remainder
		}
		sum += amount
	}

	if sum != totalAmount {
		t.Errorf("soma das parcelas %d difere do total original %d", sum, totalAmount)
	}
}

func TestAnticipationDiscountCalculation(t *testing.T) {
	annualRate := 10.0 // 10% a.a.
	monthlyRate := math.Pow(1.0+(annualRate/100.0), 1.0/12.0) - 1.0

	amountCents := int64(10000) // R$ 100,00
	monthsAhead := 6

	fv := float64(amountCents)
	pv := fv / math.Pow(1.0+monthlyRate, float64(monthsAhead))
	discount := int64(math.Round(fv - pv))

	if discount <= 0 {
		t.Errorf("desconto de antecipação deve ser positivo, obteve %d", discount)
	}

	if discount >= amountCents {
		t.Errorf("desconto %d não pode exceder o valor nominal %d", discount, amountCents)
	}
}

func TestBudgetEnvelopePercentages(t *testing.T) {
	tests := []struct {
		allocated int64
		spent     int64
		expected  string
	}{
		{allocated: 100000, spent: 50000, expected: "normal"},
		{allocated: 100000, spent: 75000, expected: "warning"},
		{allocated: 100000, spent: 90000, expected: "warning"},
		{allocated: 100000, spent: 100000, expected: "exceeded"},
		{allocated: 100000, spent: 120000, expected: "exceeded"},
	}

	for _, tt := range tests {
		pct := (float64(tt.spent) / float64(tt.allocated)) * 100.0
		var status string
		if pct >= 100.0 {
			status = "exceeded"
		} else if pct >= 75.0 {
			status = "warning"
		} else {
			status = "normal"
		}

		if status != tt.expected {
			t.Errorf("para %d/%d esperava status %s, obteve %s", tt.spent, tt.allocated, tt.expected, status)
		}
	}
}
