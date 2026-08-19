package pii

// Tokenizer replaces PII in a payload with opaque tokens before the
// payload is sent to an LLM cloud provider, and reverses the mapping
// when the response comes back.
type Tokenizer interface {
	// Tokenize replaces every PII span in text with a stable, opaque token.
	Tokenize(text string) (tokenized string, err error)

	// Detokenize replaces tokens in text with the original PII values.
	Detokenize(text string) (original string, err error)
}
