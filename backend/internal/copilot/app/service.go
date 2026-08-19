package app

import (
	"context"
	"strings"

	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/copilot/domain"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type CopilotService struct {
	agent   *CopilotAgent
	queries *sqlc.Queries
}

func NewCopilotService(agent *CopilotAgent, queries *sqlc.Queries) *CopilotService {
	return &CopilotService{
		agent:   agent,
		queries: queries,
	}
}

func (s *CopilotService) EnsureConversation(ctx context.Context, familyID, userID uuid.UUID, conversationID *uuid.UUID, firstMessage string) (uuid.UUID, error) {
	if conversationID != nil && *conversationID != uuid.Nil {
		conv, err := s.queries.GetAIConversationByID(ctx, sqlc.GetAIConversationByIDParams{
			ID:       *conversationID,
			FamilyID: familyID,
		})
		if err == nil && conv.ID != uuid.Nil {
			return conv.ID, nil
		}
	}

	title := "Conversa com Copilot"
	cleanMsg := strings.TrimSpace(firstMessage)
	if len(cleanMsg) > 0 {
		runes := []rune(cleanMsg)
		if len(runes) > 40 {
			title = string(runes[:40]) + "..."
		} else {
			title = cleanMsg
		}
	}

	newConv, err := s.queries.CreateAIConversation(ctx, sqlc.CreateAIConversationParams{
		FamilyID: familyID,
		UserID:   userID,
		Title:    title,
	})
	if err != nil {
		return uuid.Nil, err
	}
	return newConv.ID, nil
}

func (s *CopilotService) SendMessage(ctx context.Context, familyID, userID uuid.UUID, conversationID *uuid.UUID, message string) (*domain.ChatStreamDelta, error) {
	convID, err := s.EnsureConversation(ctx, familyID, userID, conversationID, message)
	if err != nil {
		return nil, err
	}

	return s.agent.Execute(ctx, familyID, userID, convID, message, nil)
}

func (s *CopilotService) StreamMessage(ctx context.Context, familyID, userID uuid.UUID, conversationID *uuid.UUID, message string, deltaChan chan<- domain.ChatStreamDelta) error {
	convID, err := s.EnsureConversation(ctx, familyID, userID, conversationID, message)
	if err != nil {
		return err
	}

	_, err = s.agent.Execute(ctx, familyID, userID, convID, message, deltaChan)
	return err
}

func (s *CopilotService) ListConversations(ctx context.Context, familyID, userID uuid.UUID) ([]domain.AIConversation, error) {
	raw, err := s.queries.ListAIConversationsByFamilyID(ctx, sqlc.ListAIConversationsByFamilyIDParams{
		FamilyID: familyID,
		UserID:   userID,
	})
	if err != nil {
		return nil, err
	}

	out := make([]domain.AIConversation, len(raw))
	for i, c := range raw {
		out[i] = domain.AIConversation{
			ID:        c.ID,
			FamilyID:  c.FamilyID,
			UserID:    c.UserID,
			Title:     c.Title,
			CreatedAt: c.CreatedAt,
			UpdatedAt: c.UpdatedAt,
		}
	}
	return out, nil
}

func (s *CopilotService) ListMessages(ctx context.Context, conversationID uuid.UUID) ([]domain.AIMessage, error) {
	raw, err := s.queries.ListAIMessagesByConversationID(ctx, conversationID)
	if err != nil {
		return nil, err
	}

	out := make([]domain.AIMessage, len(raw))
	for i, m := range raw {
		content := ""
		if m.Content != nil {
			content = *m.Content
		}
		out[i] = domain.AIMessage{
			ID:             m.ID,
			ConversationID: m.ConversationID,
			Role:           domain.MessageRole(m.Role),
			Content:        content,
			ToolCalls:      m.ToolCalls,
			ToolCallID:     m.ToolCallID,
			CreatedAt:      m.CreatedAt,
		}
	}
	return out, nil
}
