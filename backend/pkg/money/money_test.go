package money

import "testing"

func TestMoney_AddSubEqual(t *testing.T) {
	m1 := BRLFromCents(10050) // R$ 100,50
	m2 := BRLFromCents(2525)  // R$ 25,25

	sum, err := m1.Add(m2)
	if err != nil {
		t.Fatalf("Add failed: %v", err)
	}
	if sum.Cents != 12575 {
		t.Errorf("Expected 12575, got %d", sum.Cents)
	}

	diff, err := m1.Sub(m2)
	if err != nil {
		t.Fatalf("Sub failed: %v", err)
	}
	if diff.Cents != 7525 {
		t.Errorf("Expected 7525, got %d", diff.Cents)
	}

	if m1.Equal(m2) {
		t.Errorf("m1 should not equal m2")
	}

	m3 := New(10050, 2, BRL)
	if !m1.Equal(m3) {
		t.Errorf("m1 should equal m3")
	}
}

func TestMoney_CurrencyMismatch(t *testing.T) {
	m1 := BRLFromCents(1000)
	m2 := New(1000, 2, USD)

	_, err := m1.Add(m2)
	if err != ErrCurrencyMismatch {
		t.Errorf("Expected ErrCurrencyMismatch, got %v", err)
	}
}
