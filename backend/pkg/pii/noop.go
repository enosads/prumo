package pii

// NoopTokenizer passes strings through without modification.
type NoopTokenizer struct{}

func NewNoopTokenizer() *NoopTokenizer {
	return &NoopTokenizer{}
}

func (n *NoopTokenizer) Tokenize(text string) (string, error) {
	return text, nil
}

func (n *NoopTokenizer) Detokenize(text string) (string, error) {
	return text, nil
}
