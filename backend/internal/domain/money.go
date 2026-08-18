package domain

import (
	"fmt"
)

// Cents representa um valor monetário em centavos para evitar erros de precisão float.
// Exemplo: R$ 49,90 = 4990 cents.
type Cents int64

func (c Cents) ToFloat() float64 {
	return float64(c) / 100.0
}

func (c Cents) FormatBRL() string {
	val := c.ToFloat()
	return fmt.Sprintf("R$ %.2f", val)
}

func FromFloat(val float64) Cents {
	return Cents(val * 100.0)
}
