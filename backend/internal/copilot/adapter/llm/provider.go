package llm

import (
	"context"

	"github.com/enosads/prumo/backend/internal/copilot/domain"
)

type LLMMessage struct {
	Role       string            `json:"role"`
	Content    string            `json:"content"`
	ToolCalls  []domain.ToolCall `json:"tool_calls,omitempty"`
	ToolCallID *string           `json:"tool_call_id,omitempty"`
}

type LLMResponse struct {
	Content   string
	ToolCalls []domain.ToolCall
}

type LLMProvider interface {
	Name() string
	Chat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) (*LLMResponse, error)
	StreamChat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error)
}
