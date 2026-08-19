package llm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/enosads/prumo/backend/internal/copilot/domain"
)

type OpenAIProvider struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewOpenAIProvider(apiKey, model string) *OpenAIProvider {
	if model == "" {
		model = "gpt-4o"
	}
	return &OpenAIProvider{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (o *OpenAIProvider) Name() string {
	return "openai"
}

type openAITool struct {
	Type     string            `json:"type"`
	Function openAIFunctionDef `json:"function"`
}

type openAIFunctionDef struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	Parameters  interface{} `json:"parameters"`
}

type openAIMessage struct {
	Role       string            `json:"role"`
	Content    string            `json:"content,omitempty"`
	ToolCalls  []openAIToolCall  `json:"tool_calls,omitempty"`
	ToolCallID string            `json:"tool_call_id,omitempty"`
}

type openAIToolCall struct {
	Index    int                `json:"index,omitempty"`
	ID       string             `json:"id,omitempty"`
	Type     string             `json:"type,omitempty"`
	Function openAIFunctionCall `json:"function"`
}

type openAIFunctionCall struct {
	Name      string `json:"name,omitempty"`
	Arguments string `json:"arguments,omitempty"`
}

type openAIRequest struct {
	Model    string          `json:"model"`
	Messages []openAIMessage `json:"messages"`
	Tools    []openAITool    `json:"tools,omitempty"`
	Stream   bool            `json:"stream,omitempty"`
}

func (o *OpenAIProvider) Chat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) (*LLMResponse, error) {
	if o.apiKey == "" {
		return nil, fmt.Errorf("openai: API key não configurada")
	}

	reqBody := o.buildRequest(systemPrompt, messages, tools, false)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.openai.com/v1/chat/completions", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+o.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("openai error (%d): %s", resp.StatusCode, string(b))
	}

	var res struct {
		Choices []struct {
			Message struct {
				Content   string           `json:"content"`
				ToolCalls []openAIToolCall `json:"tool_calls"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, err
	}

	if len(res.Choices) == 0 {
		return &LLMResponse{}, nil
	}

	choice := res.Choices[0].Message
	out := &LLMResponse{Content: choice.Content}
	for _, tc := range choice.ToolCalls {
		out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
			ID:        tc.ID,
			Name:      tc.Function.Name,
			Arguments: json.RawMessage(tc.Function.Arguments),
		})
	}

	return out, nil
}

func (o *OpenAIProvider) StreamChat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error) {
	if o.apiKey == "" {
		return nil, fmt.Errorf("openai: API key não configurada")
	}

	reqBody := o.buildRequest(systemPrompt, messages, tools, true)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.openai.com/v1/chat/completions", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+o.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := o.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("openai stream error (%d): %s", resp.StatusCode, string(b))
	}

	reader := bufio.NewReader(resp.Body)
	out := &LLMResponse{}
	toolCallsMap := make(map[int]*openAIToolCall)

	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			break
		}

		var chunk struct {
			Choices []struct {
				Delta struct {
					Content   string           `json:"content"`
					ToolCalls []openAIToolCall `json:"tool_calls"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}

		if len(chunk.Choices) == 0 {
			continue
		}

		delta := chunk.Choices[0].Delta
		if delta.Content != "" {
			out.Content += delta.Content
			if textChunkChan != nil {
				textChunkChan <- delta.Content
			}
		}

		for _, tc := range delta.ToolCalls {
			idx := tc.Index
			existing, ok := toolCallsMap[idx]
			if !ok {
				tcCopy := tc
				toolCallsMap[idx] = &tcCopy
			} else {
				if tc.ID != "" {
					existing.ID = tc.ID
				}
				if tc.Function.Name != "" {
					existing.Function.Name += tc.Function.Name
				}
				if tc.Function.Arguments != "" {
					existing.Function.Arguments += tc.Function.Arguments
				}
			}
		}
	}

	for i := 0; i < len(toolCallsMap); i++ {
		if tc, ok := toolCallsMap[i]; ok {
			out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
				ID:        tc.ID,
				Name:      tc.Function.Name,
				Arguments: json.RawMessage(tc.Function.Arguments),
			})
		}
	}

	return out, nil
}

func (o *OpenAIProvider) buildRequest(systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, stream bool) openAIRequest {
	var oaiTools []openAITool
	for _, t := range tools {
		oaiTools = append(oaiTools, openAITool{
			Type: "function",
			Function: openAIFunctionDef{
				Name:        t.Name,
				Description: t.Description,
				Parameters:  t.Parameters,
			},
		})
	}

	var oaiMessages []openAIMessage
	if systemPrompt != "" {
		oaiMessages = append(oaiMessages, openAIMessage{
			Role:    "system",
			Content: systemPrompt,
		})
	}

	for _, m := range messages {
		msg := openAIMessage{
			Role:    m.Role,
			Content: m.Content,
		}
		if m.ToolCallID != nil {
			msg.ToolCallID = *m.ToolCallID
		}
		for _, tc := range m.ToolCalls {
			msg.ToolCalls = append(msg.ToolCalls, openAIToolCall{
				ID:   tc.ID,
				Type: "function",
				Function: openAIFunctionCall{
					Name:      tc.Name,
					Arguments: string(tc.Arguments),
				},
			})
		}
		oaiMessages = append(oaiMessages, msg)
	}

	return openAIRequest{
		Model:    o.model,
		Messages: oaiMessages,
		Tools:    oaiTools,
		Stream:   stream,
	}
}
