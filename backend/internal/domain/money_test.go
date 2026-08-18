package domain

import (
	"testing"
)

func TestMoneyOperations(t *testing.T) {
	c := Cents(4990)
	if c.ToFloat() != 49.90 {
		t.Errorf("esperava 49.90, obteve %f", c.ToFloat())
	}

	if c.FormatBRL() != "R$ 49.90" {
		t.Errorf("esperava 'R$ 49.90', obteve '%s'", c.FormatBRL())
	}

	fromF := FromFloat(125.50)
	if fromF != Cents(12550) {
		t.Errorf("esperava 12550, obteve %d", fromF)
	}
}
