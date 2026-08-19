package pii

import (
	"fmt"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
)

var (
	cpfRegex   = regexp.MustCompile(`\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b`)
	cnpjRegex  = regexp.MustCompile(`\b\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\b`)
	cardRegex  = regexp.MustCompile(`\b(?:\d{4}[ -]?){3}\d{4}\b`)
	emailRegex = regexp.MustCompile(`\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b`)
)

// MemoryTokenizer is an in-memory, deterministic tokenizer for PII.
type MemoryTokenizer struct {
	mu      sync.RWMutex
	forward map[string]string // original -> token
	reverse map[string]string // token -> original
	counter atomic.Int64
}

// NewMemoryTokenizer constructs a new MemoryTokenizer.
func NewMemoryTokenizer() *MemoryTokenizer {
	return &MemoryTokenizer{
		forward: make(map[string]string),
		reverse: make(map[string]string),
	}
}

// Register pre-seeds a known PII -> token mapping (e.g. user names or known IDs).
func (m *MemoryTokenizer) Register(original, token string) {
	if original == "" || token == "" {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.forward[original] = token
	m.reverse[token] = original
}

// Tokenize masks detected PII entities (CPF, CNPJ, Cartões, Emails e strings registradas).
func (m *MemoryTokenizer) Tokenize(text string) (string, error) {
	if text == "" {
		return "", nil
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// 1. Aplica mapeamentos pré-registrados
	for orig, tok := range m.forward {
		if strings.Contains(text, orig) {
			text = strings.ReplaceAll(text, orig, tok)
		}
	}

	// 2. Detecta e tokeniza CPFs
	text = cpfRegex.ReplaceAllStringFunc(text, func(match string) string {
		return m.getOrCreateTokenLocked(match, "CPF")
	})

	// 3. Detecta e tokeniza CNPJs
	text = cnpjRegex.ReplaceAllStringFunc(text, func(match string) string {
		return m.getOrCreateTokenLocked(match, "CNPJ")
	})

	// 4. Detecta e tokeniza números de cartão de crédito
	text = cardRegex.ReplaceAllStringFunc(text, func(match string) string {
		return m.getOrCreateTokenLocked(match, "CARD")
	})

	// 5. Detecta e tokeniza e-mails
	text = emailRegex.ReplaceAllStringFunc(text, func(match string) string {
		return m.getOrCreateTokenLocked(match, "EMAIL")
	})

	return text, nil
}

func (m *MemoryTokenizer) getOrCreateTokenLocked(original, kind string) string {
	if tok, ok := m.forward[original]; ok {
		return tok
	}
	n := m.counter.Add(1)
	tok := fmt.Sprintf("__PII_%s_%d__", kind, n)
	m.forward[original] = tok
	m.reverse[tok] = original
	return tok
}

// Detokenize replaces all tokens in text with their original values.
func (m *MemoryTokenizer) Detokenize(text string) (string, error) {
	if text == "" {
		return "", nil
	}

	m.mu.RLock()
	defer m.mu.RUnlock()

	for tok, orig := range m.reverse {
		if strings.Contains(text, tok) {
			text = strings.ReplaceAll(text, tok, orig)
		}
	}

	return text, nil
}
