package domain

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type AIConversation struct {
	ID        uuid.UUID
	FamilyID  uuid.UUID
	UserID    uuid.UUID
	Title     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type MessageRole string

const (
	RoleUser      MessageRole = "user"
	RoleAssistant MessageRole = "assistant"
	RoleSystem    MessageRole = "system"
	RoleTool      MessageRole = "tool"
)

type AIMessage struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	Role           MessageRole
	Content        string
	ToolCalls      json.RawMessage
	ToolCallID     *string
	CreatedAt      time.Time
}

type ToolExecutionStatus string

const (
	StatusPendingApproval ToolExecutionStatus = "pending_approval"
	StatusApproved        ToolExecutionStatus = "approved"
	StatusRejected        ToolExecutionStatus = "rejected"
	StatusExecuted        ToolExecutionStatus = "executed"
	StatusFailed          ToolExecutionStatus = "failed"
)

type AIToolExecution struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	FamilyID       uuid.UUID
	UserID         uuid.UUID
	ToolName       string
	Parameters     json.RawMessage
	Result         json.RawMessage
	Status         ToolExecutionStatus
	ApprovalToken  *string
	ExecutedAt     *time.Time
	CreatedAt      time.Time
}

type ToolParameterSchema struct {
	Type        string                 `json:"type"`
	Description string                 `json:"description,omitempty"`
	Properties  map[string]interface{} `json:"properties,omitempty"`
	Required    []string               `json:"required,omitempty"`
}

type ToolDefinition struct {
	Name        string              `json:"name"`
	Description string              `json:"description"`
	Parameters  ToolParameterSchema `json:"parameters"`
}

type ToolCall struct {
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

type ToolResult struct {
	ToolCallID string          `json:"tool_call_id"`
	ToolName   string          `json:"tool_name"`
	Result     json.RawMessage `json:"result"`
	Error      *string         `json:"error,omitempty"`
}

type ChatDeltaType string

const (
	DeltaMessageStart    ChatDeltaType = "message_start"
	DeltaText            ChatDeltaType = "text_delta"
	DeltaToolCall        ChatDeltaType = "tool_call"
	DeltaToolResult      ChatDeltaType = "tool_result"
	DeltaMessageComplete ChatDeltaType = "message_complete"
	DeltaError           ChatDeltaType = "error"
)

type ChatStreamDelta struct {
	Type           ChatDeltaType    `json:"type"`
	ConversationID *uuid.UUID       `json:"conversation_id,omitempty"`
	MessageID      *uuid.UUID       `json:"message_id,omitempty"`
	Delta          *string          `json:"delta,omitempty"`
	FullText       *string          `json:"full_text,omitempty"`
	ToolCall       *ToolCall        `json:"tool_call,omitempty"`
	ToolResult     *ToolResult      `json:"tool_result,omitempty"`
	Error          *string          `json:"error,omitempty"`
}
