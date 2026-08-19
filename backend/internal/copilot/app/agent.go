package app

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/copilot/adapter/llm"
	"github.com/enosads/prumo/backend/internal/copilot/domain"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
	"github.com/enosads/prumo/backend/pkg/pii"
)

const systemPrompt = `Você é o Copilot de IA do Prumo, especialista em finanças pessoais e economia familiar.
Suas responsabilidades:
1. Analisar com precisão saldos, extratos, faturas de cartão de crédito e envelopes de orçamento.
2. Responder sempre em Português do Brasil (pt-BR) com clareza, empatia e foco na saúde financeira da família.
3. Formatar valores monetários em Reais (ex: R$ 1.250,00).
4. Usar as ferramentas (tools) disponíveis para buscar dados em tempo real sempre que o usuário fizer perguntas sobre patrimônio, gastos, orçamentos ou faturas.
5. Utilizar formatação Markdown (negrito, listas, tabelas) para deixar a leitura agradável e direta.`

type CopilotAgent struct {
	providers []llm.LLMProvider
	tools     *ToolRegistry
	tokenizer pii.Tokenizer
	queries   *sqlc.Queries
}

func NewCopilotAgent(providers []llm.LLMProvider, tools *ToolRegistry, tokenizer pii.Tokenizer, queries *sqlc.Queries) *CopilotAgent {
	if tokenizer == nil {
		tokenizer = pii.NewMemoryTokenizer()
	}
	return &CopilotAgent{
		providers: providers,
		tools:     tools,
		tokenizer: tokenizer,
		queries:   queries,
	}
}

func (a *CopilotAgent) Execute(
	ctx context.Context,
	familyID, userID, conversationID uuid.UUID,
	rawUserMessage string,
	deltaChan chan<- domain.ChatStreamDelta,
) (*domain.ChatStreamDelta, error) {
	// 1. Tokenização de PII antes de enviar ao LLM
	tokenizedUserMsg, err := a.tokenizer.Tokenize(rawUserMessage)
	if err != nil {
		tokenizedUserMsg = rawUserMessage
	}

	// 2. Persistência da mensagem do usuário no banco
	_, err = a.queries.CreateAIMessage(ctx, sqlc.CreateAIMessageParams{
		ConversationID: conversationID,
		Role:           string(domain.RoleUser),
		Content:        &rawUserMessage,
		ToolCalls:      nil,
		ToolCallID:     nil,
	})
	if err != nil {
		log.Printf("[Copilot] Erro ao salvar mensagem do usuário: %v", err)
	}

	// 3. Notifica início do streaming
	if deltaChan != nil {
		deltaChan <- domain.ChatStreamDelta{
			Type:           domain.DeltaMessageStart,
			ConversationID: &conversationID,
		}
	}

	// 4. Carrega histórico recente da conversa (últimas 10 mensagens)
	historyRows, _ := a.queries.ListAIMessagesByConversationID(ctx, conversationID)
	var llmMessages []llm.LLMMessage
	for _, h := range historyRows {
		content := ""
		if h.Content != nil {
			content = *h.Content
		}
		var tc []domain.ToolCall
		if len(h.ToolCalls) > 0 {
			_ = json.Unmarshal(h.ToolCalls, &tc)
		}
		llmMessages = append(llmMessages, llm.LLMMessage{
			Role:       h.Role,
			Content:    content,
			ToolCalls:  tc,
			ToolCallID: h.ToolCallID,
		})
	}

	if len(llmMessages) == 0 || llmMessages[len(llmMessages)-1].Role != "user" {
		llmMessages = append(llmMessages, llm.LLMMessage{
			Role:    "user",
			Content: tokenizedUserMsg,
		})
	}

	toolDefs := a.tools.GetToolDefinitions()

	var finalResponse string
	maxTurns := 5

	for turn := 0; turn < maxTurns; turn++ {
		// Canal intermediário para receber chunks de texto do provider
		chunkChan := make(chan string, 100)
		doneChunk := make(chan struct{})

		var streamedText strings.Builder
		go func() {
			defer close(doneChunk)
			for chunk := range chunkChan {
				streamedText.WriteString(chunk)
				if deltaChan != nil {
					detokChunk, _ := a.tokenizer.Detokenize(chunk)
					deltaChan <- domain.ChatStreamDelta{
						Type:           domain.DeltaText,
						ConversationID: &conversationID,
						Delta:          &detokChunk,
					}
				}
			}
		}()

		var resp *llm.LLMResponse
		var llmErr error

		// Tenta os provedores configurados em ordem de prioridade
		for _, prov := range a.providers {
			resp, llmErr = prov.StreamChat(ctx, systemPrompt, llmMessages, toolDefs, chunkChan)
			if llmErr == nil && resp != nil {
				break
			}
			log.Printf("[Copilot] Provedor %s falhou ou não configurado (%v), tentando próximo...", prov.Name(), llmErr)
		}
		close(chunkChan)
		<-doneChunk

		if resp == nil {
			errText := "Não foi possível conectar aos provedores de inteligência artificial. Tente novamente em instantes."
			if deltaChan != nil {
				deltaChan <- domain.ChatStreamDelta{
					Type:           domain.DeltaError,
					ConversationID: &conversationID,
					Error:          &errText,
				}
			}
			return nil, fmt.Errorf("todos os provedores falharam: %v", llmErr)
		}

		// Se o LLM solicitou a execução de tools
		if len(resp.ToolCalls) > 0 {
			var tcRaw json.RawMessage
			tcBytes, _ := json.Marshal(resp.ToolCalls)
			tcRaw = tcBytes

			// Salva a intenção do assistente com tool_calls
			_, _ = a.queries.CreateAIMessage(ctx, sqlc.CreateAIMessageParams{
				ConversationID: conversationID,
				Role:           string(domain.RoleAssistant),
				Content:        &resp.Content,
				ToolCalls:      tcRaw,
				ToolCallID:     nil,
			})

			llmMessages = append(llmMessages, llm.LLMMessage{
				Role:      "assistant",
				Content:   resp.Content,
				ToolCalls: resp.ToolCalls,
			})

			for _, tc := range resp.ToolCalls {
				tcCopy := tc
				if deltaChan != nil {
					deltaChan <- domain.ChatStreamDelta{
						Type:           domain.DeltaToolCall,
						ConversationID: &conversationID,
						ToolCall:       &tcCopy,
					}
				}

				// Registra execução da ferramenta na tabela de auditoria
				execRecord, _ := a.queries.CreateAIToolExecution(ctx, sqlc.CreateAIToolExecutionParams{
					ConversationID: conversationID,
					FamilyID:       familyID,
					UserID:         userID,
					ToolName:       tc.Name,
					Parameters:     tc.Arguments,
					Status:         string(domain.StatusApproved),
					ApprovalToken:  nil,
				})

				toolResultJSON, execErr := a.tools.ExecuteTool(ctx, familyID, userID, tc.Name, tc.Arguments)
				var errStr *string
				if execErr != nil {
					s := execErr.Error()
					errStr = &s
					toolResultJSON = []byte(fmt.Sprintf(`{"error": "%s"}`, s))
				}

				if execRecord.ID != uuid.Nil {
					status := string(domain.StatusExecuted)
					if execErr != nil {
						status = string(domain.StatusFailed)
					}
					_, _ = a.queries.UpdateAIToolExecutionStatus(ctx, sqlc.UpdateAIToolExecutionStatusParams{
						ID:     execRecord.ID,
						Status: status,
						Result: toolResultJSON,
					})
				}

				resObj := domain.ToolResult{
					ToolCallID: tc.ID,
					ToolName:   tc.Name,
					Result:     toolResultJSON,
					Error:      errStr,
				}

				if deltaChan != nil {
					deltaChan <- domain.ChatStreamDelta{
						Type:           domain.DeltaToolResult,
						ConversationID: &conversationID,
						ToolResult:     &resObj,
					}
				}

				// Adiciona o resultado da ferramenta na conversa
				tcID := tc.ID
				resultStr := string(toolResultJSON)
				_, _ = a.queries.CreateAIMessage(ctx, sqlc.CreateAIMessageParams{
					ConversationID: conversationID,
					Role:           string(domain.RoleTool),
					Content:        &resultStr,
					ToolCalls:      nil,
					ToolCallID:     &tcID,
				})

				llmMessages = append(llmMessages, llm.LLMMessage{
					Role:       "tool",
					Content:    resultStr,
					ToolCallID: &tcID,
				})
			}

			// Continua o loop para que o LLM responda com base nos resultados das tools
			continue
		}

		// Se não houve tool_calls, temos a resposta textual final
		finalResponse = resp.Content
		if finalResponse == "" {
			finalResponse = streamedText.String()
		}
		break
	}

	// Detokeniza a resposta antes de enviar o evento final e persistir
	detokFinal, err := a.tokenizer.Detokenize(finalResponse)
	if err != nil {
		detokFinal = finalResponse
	}

	assistantMsg, _ := a.queries.CreateAIMessage(ctx, sqlc.CreateAIMessageParams{
		ConversationID: conversationID,
		Role:           string(domain.RoleAssistant),
		Content:        &detokFinal,
		ToolCalls:      nil,
		ToolCallID:     nil,
	})

	completeDelta := &domain.ChatStreamDelta{
		Type:           domain.DeltaMessageComplete,
		ConversationID: &conversationID,
		MessageID:      &assistantMsg.ID,
		FullText:       &detokFinal,
	}

	if deltaChan != nil {
		deltaChan <- *completeDelta
	}

	return completeDelta, nil
}
