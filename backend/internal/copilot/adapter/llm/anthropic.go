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

type AnthropicProvider struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewAnthropicProvider(apiKey, model string) *AnthropicProvider {
	if model == "" {
		model = "claude-3-7-sonnet-20250219"
	}
	return &AnthropicProvider{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (a *AnthropicProvider) Name() string {
	return "anthropic"
}

type anthropicTool struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	InputSchema interface{} `json:"input_schema"`
}

type anthropicContentBlock struct {
	Type  string          `json:"type"`
	Text  string          `json:"text,omitempty"`
	ID    string          `json:"id,omitempty"`
	Name  string          `json:"name,omitempty"`
	Input json.RawMessage `json:"input,omitempty"`
}

type anthropicMessage struct {
	Role    string                  `json:"role"`
	Content []anthropicContentBlock `json:"content"`
}

type anthropicRequest struct {
	Model     string             `json:"model"`
	System    string             `json:"system,omitempty"`
	Messages  []anthropicMessage `json:"messages"`
	Tools     []anthropicTool    `json:"tools,omitempty"`
	MaxTokens int                `json:"max_tokens"`
	Stream    bool               `json:"stream,omitempty"`
}

func (a *AnthropicProvider) Chat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) (*LLMResponse, error) {
	if a.apiKey == "" {
		return nil, fmt.Errorf("anthropic: API key não configurada")
	}

	reqBody := a.buildRequest(systemPrompt, messages, tools, false)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.anthropic.com/v1/messages", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("x-api-key", a.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("anthropic error (%d): %s", resp.StatusCode, string(b))
	}

	var res struct {
		Content []anthropicContentBlock `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		return nil, err
	}

	out := &LLMResponse{}
	for _, block := range res.Content {
		if block.Type == "text" {
			out.Content += block.Text
		} else if block.Type == "tool_use" {
			out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
				ID:        block.ID,
				Name:      block.Name,
				Arguments: block.Input,
			})
		}
	}

	return out, nil
}

func (a *AnthropicProvider) StreamChat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error) {
	if a.apiKey == "" {
		return nil, fmt.Errorf("anthropic: API key não configurada")
	}

	reqBody := a.buildRequest(systemPrompt, messages, tools, true)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.anthropic.com/v1/messages", bytes.NewReader(bodyBytes))
	if err != nil {
		return nil, err
	}
	req.Header.Set("x-api-key", a.apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("anthropic stream error (%d): %s", resp.StatusCode, string(b))
	}

	reader := bufio.NewReader(resp.Body)
	out := &LLMResponse{}
	var currentToolID, currentToolName string
	var currentToolInput strings.Builder

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

		var event struct {
			Type  string `json:"type"`
			Delta struct {
				Type         string `json:"type"`
				Text         string `json:"text"`
				PartialJSON  string `json:"partial_json"`
			} `json:"delta"`
			ContentBlock struct {
				Type string `json:"type"`
				ID   string `json:"id"`
				Name string `json:"name"`
			} `json:"content_block"`
		}
		if err := json.Unmarshal([]byte(data), &event); err != nil {
			continue
		}

		switch event.Type {
		case "content_block_start":
			if event.ContentBlock.Type == "tool_use" {
				currentToolID = event.ContentBlock.ID
				currentToolName = event.ContentBlock.Name
				currentToolInput.Reset()
			}
		case "content_block_delta":
			if event.Delta.Type == "text_delta" {
				out.Content += event.Delta.Text
				if textChunkChan != nil {
					textChunkChan <- event.Delta.Text
				}
			} else if event.Delta.Type == "input_json_delta" {
				currentToolInput.WriteString(event.Delta.PartialJSON)
			}
		case "content_block_stop":
			if currentToolName != "" {
				out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
					ID:        currentToolID,
					Name:      currentToolName,
					Arguments: json.RawMessage(currentToolInput.String()),
				})
				currentToolName = ""
			}
		}
	}

	return out, nil
}

func (a *AnthropicProvider) buildRequest(systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, stream bool) anthropicRequest {
	var antTools []anthropicTool
	for _, t := range tools {
		antTools = append(antTools, anthropicTool{
			Name:        t.Name,
			Description: t.Description,
			InputSchema: t.Parameters,
		})
	}

	var antMessages []anthropicMessage
	for _, m := range messages {
		if m.Role == "system" {
			continue
		}
		role := m.Role
		if role == "tool" {
			role = "user"
		}

		var blocks []anthropicContentBlock
		if m.Content != "" {
			blocks = append(blocks, anthropicContentBlock{
				Type: "text",
				Text: m.Content,
			})
		}
		for _, tc := range m.ToolCalls {
			blocks = append(blocks, anthropicContentBlock{
				Type:  "tool_use",
				ID:    tc.ID,
				Name:  tc.Name,
				Input: tc.Arguments,
			})
		}

		antMessages = append(antMessages, anthropicMessage{
			Role:    role,
			Content: blocks,
		})
	}

	return anthropicRequest{
		Model:     a.model,
		System:    systemPrompt,
		Messages:  antMessages,
		Tools:     antTools,
		MaxTokens: 4096,
		Stream:    stream,
	}
}
