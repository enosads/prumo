package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	copilotDomain "github.com/enosads/prumo/backend/internal/copilot/domain"
)

type SendChatMessageInput struct {
	Body struct {
		ConversationID *uuid.UUID `json:"conversation_id,omitempty" doc:"ID da conversa existente ou omita para criar uma nova"`
		Message        string     `json:"message" minLength:"1" doc:"Mensagem ou comando em linguagem natural"`
		Stream         *bool      `json:"stream,omitempty" default:"false" doc:"Indica se deve responder síncrono ou via streaming SSE"`
	}
}

type SendChatMessageOutput struct {
	Body struct {
		ConversationID uuid.UUID `json:"conversation_id"`
		MessageID      uuid.UUID `json:"message_id"`
		Response       string    `json:"response"`
	}
}

type ListAIConversationsOutput struct {
	Body struct {
		Conversations []copilotDomain.AIConversation `json:"conversations"`
	}
}

type ListAIMessagesInput struct {
	ID uuid.UUID `path:"id" doc:"ID da conversa"`
}

type ListAIMessagesOutput struct {
	Body struct {
		Messages []copilotDomain.AIMessage `json:"messages"`
	}
}

func (s *Server) registerAIRoutes(api huma.API, r chi.Router) {
	// Endpoint síncrono (OpenAPI)
	huma.Register(api, huma.Operation{
		OperationID: "sendAIChatMessage",
		Method:      http.MethodPost,
		Path:        "/v1/ai/chat",
		Summary:     "Envia uma mensagem para o Copilot de IA financeiro",
		Tags:        []string{"Copilot de IA"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *SendChatMessageInput) (*SendChatMessageOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		result, err := s.copilot.SendMessage(ctx, *uCtx.FamilyID, uCtx.UserID, input.Body.ConversationID, input.Body.Message)
		if err != nil {
			return nil, httpErrorInternal(fmt.Sprintf("Erro ao processar mensagem do Copilot: %v", err))
		}

		resp := &SendChatMessageOutput{}
		if result.ConversationID != nil {
			resp.Body.ConversationID = *result.ConversationID
		}
		if result.MessageID != nil {
			resp.Body.MessageID = *result.MessageID
		}
		if result.FullText != nil {
			resp.Body.Response = *result.FullText
		}

		return resp, nil
	})

	// Endpoint de listagem de conversas
	huma.Register(api, huma.Operation{
		OperationID: "listAIConversations",
		Method:      http.MethodGet,
		Path:        "/v1/ai/conversations",
		Summary:     "Lista as conversas recentes do Copilot no núcleo familiar",
		Tags:        []string{"Copilot de IA"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*ListAIConversationsOutput, error) {
		uCtx, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		conversations, err := s.copilot.ListConversations(ctx, *uCtx.FamilyID, uCtx.UserID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar conversas do Copilot")
		}

		resp := &ListAIConversationsOutput{}
		resp.Body.Conversations = conversations
		return resp, nil
	})

	// Endpoint de mensagens de uma conversa
	huma.Register(api, huma.Operation{
		OperationID: "listAIMessages",
		Method:      http.MethodGet,
		Path:        "/v1/ai/conversations/{id}/messages",
		Summary:     "Lista o histórico de mensagens de uma conversa com o Copilot",
		Tags:        []string{"Copilot de IA"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *ListAIMessagesInput) (*ListAIMessagesOutput, error) {
		_, err := requireFamily(ctx)
		if err != nil {
			return nil, err
		}

		messages, err := s.copilot.ListMessages(ctx, input.ID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao listar mensagens")
		}

		resp := &ListAIMessagesOutput{}
		resp.Body.Messages = messages
		return resp, nil
	})

	// Endpoint SSE Streaming nativo via Chi
	r.Post("/v1/ai/chat/stream", s.streamChatHandler)
}

func (s *Server) streamChatHandler(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	uCtx, err := requireFamily(r.Context())
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "unauthorized", "message": "Autenticação necessária"})
		return
	}

	var req struct {
		ConversationID *uuid.UUID `json:"conversation_id"`
		Message        string     `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "invalid_request", "message": "Corpo da requisição inválido"})
		return
	}

	if req.Message == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "empty_message", "message": "Mensagem não pode ser vazia"})
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	deltaChan := make(chan copilotDomain.ChatStreamDelta, 100)
	done := make(chan struct{})

	go func() {
		defer close(done)
		for delta := range deltaChan {
			data, err := json.Marshal(delta)
			if err != nil {
				continue
			}
			_, _ = fmt.Fprintf(w, "event: %s\ndata: %s\n\n", delta.Type, string(data))
			flusher.Flush()
		}
	}()

	err = s.copilot.StreamMessage(r.Context(), *uCtx.FamilyID, uCtx.UserID, req.ConversationID, req.Message, deltaChan)
	close(deltaChan)
	<-done

	if err != nil {
		errData, _ := json.Marshal(map[string]string{"error": err.Error()})
		_, _ = fmt.Fprintf(w, "event: error\ndata: %s\n\n", string(errData))
		flusher.Flush()
	}
}
