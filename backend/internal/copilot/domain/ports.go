package domain

import (
	"context"

	"github.com/google/uuid"
)

type CopilotPort interface {
	SendMessage(ctx context.Context, familyID, userID uuid.UUID, conversationID *uuid.UUID, message string) (*ChatStreamDelta, error)
	StreamMessage(ctx context.Context, familyID, userID uuid.UUID, conversationID *uuid.UUID, message string, deltaChan chan<- ChatStreamDelta) error
	ListConversations(ctx context.Context, familyID, userID uuid.UUID) ([]AIConversation, error)
	ListMessages(ctx context.Context, conversationID uuid.UUID) ([]AIMessage, error)
}
