package pii

import (
	"strings"
	"testing"
)

func TestMemoryTokenizer_TokenizeAndDetokenize(t *testing.T) {
	tok := NewMemoryTokenizer()
	tok.Register("Enos Silva", "__USER_1__")

	input := "Olá Enos Silva, seu CPF é 123.456.789-00 e seu cartão é 4532 1234 5678 9012. Contato: enos@prumo.app"
	tokenized, err := tok.Tokenize(input)
	if err != nil {
		t.Fatalf("Tokenize failed: %v", err)
	}

	if strings.Contains(tokenized, "123.456.789-00") {
		t.Errorf("CPF was not masked: %s", tokenized)
	}
	if strings.Contains(tokenized, "4532 1234 5678 9012") {
		t.Errorf("Card was not masked: %s", tokenized)
	}
	if strings.Contains(tokenized, "enos@prumo.app") {
		t.Errorf("Email was not masked: %s", tokenized)
	}
	if !strings.Contains(tokenized, "__USER_1__") {
		t.Errorf("Custom mapping was not applied: %s", tokenized)
	}

	detokenized, err := tok.Detokenize(tokenized)
	if err != nil {
		t.Fatalf("Detokenize failed: %v", err)
	}

	if detokenized != input {
		t.Errorf("Detokenized does not match input:\nExpected: %s\nGot: %s", input, detokenized)
	}
}
