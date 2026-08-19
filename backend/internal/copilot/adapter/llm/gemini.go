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

type GeminiProvider struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewGeminiProvider(apiKey, model string) *GeminiProvider {
	if model == "" {
		model = "gemini-2.5-flash"
	}
	return &GeminiProvider{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

func (g *GeminiProvider) Name() string {
	return fmt.Sprintf("gemini (%s)", g.model)
}

type geminiPart struct {
	Text             string              `json:"text,omitempty"`
	FunctionCall     *geminiFunctionCall `json:"functionCall,omitempty"`
	FunctionResponse *geminiFunctionResp `json:"functionResponse,omitempty"`
}

type geminiFunctionCall struct {
	Name string          `json:"name"`
	Args json.RawMessage `json:"args"`
}

type geminiFunctionResp struct {
	Name     string                 `json:"name"`
	Response map[string]interface{} `json:"response"`
}

type geminiContent struct {
	Role  string       `json:"role"`
	Parts []geminiPart `json:"parts"`
}

type geminiRequest struct {
	Contents          []geminiContent `json:"contents"`
	SystemInstruction *geminiContent  `json:"systemInstruction,omitempty"`
	Tools             []geminiTool    `json:"tools,omitempty"`
}

type geminiTool struct {
	FunctionDeclarations []geminiFunctionDecl `json:"functionDeclarations"`
}

type geminiFunctionDecl struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	Parameters  interface{} `json:"parameters"`
}

func (g *GeminiProvider) Chat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) (*LLMResponse, error) {
	if g.apiKey == "" {
		return nil, fmt.Errorf("gemini: API key não configurada")
	}

	reqBody := g.buildRequest(systemPrompt, messages, tools)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	modelsToTry := []string{g.model, "gemini-2.5-flash", "gemini-2.0-flash"}
	var lastErr error

	for _, modelName := range uniqueStrings(modelsToTry) {
		url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", modelName, g.apiKey)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := g.httpClient.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode == http.StatusNotFound {
			resp.Body.Close()
			lastErr = fmt.Errorf("modelo %s não encontrado", modelName)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			return nil, fmt.Errorf("gemini error (%d): %s", resp.StatusCode, string(b))
		}

		var res struct {
			Candidates []struct {
				Content struct {
					Parts []geminiPart `json:"parts"`
				} `json:"content"`
			} `json:"candidates"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
			resp.Body.Close()
			return nil, err
		}
		resp.Body.Close()

		if len(res.Candidates) == 0 {
			return &LLMResponse{}, nil
		}

		out := &LLMResponse{}
		for _, part := range res.Candidates[0].Content.Parts {
			if part.Text != "" {
				out.Content += part.Text
			}
			if part.FunctionCall != nil {
				out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
					ID:        fmt.Sprintf("call_%d", time.Now().UnixNano()),
					Name:      part.FunctionCall.Name,
					Arguments: part.FunctionCall.Args,
				})
			}
		}

		return out, nil
	}

	return nil, lastErr
}

func (g *GeminiProvider) StreamChat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error) {
	if g.apiKey == "" {
		return nil, fmt.Errorf("gemini: API key não configurada")
	}

	reqBody := g.buildRequest(systemPrompt, messages, tools)
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	modelsToTry := []string{g.model, "gemini-2.5-flash", "gemini-2.0-flash"}
	var lastErr error

	for _, modelName := range uniqueStrings(modelsToTry) {
		url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:streamGenerateContent?alt=sse&key=%s", modelName, g.apiKey)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := g.httpClient.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode == http.StatusNotFound {
			resp.Body.Close()
			lastErr = fmt.Errorf("modelo %s não encontrado", modelName)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			return nil, fmt.Errorf("gemini stream error (%d): %s", resp.StatusCode, string(b))
		}

		reader := bufio.NewReader(resp.Body)
		out := &LLMResponse{}

		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				if err == io.EOF {
					break
				}
				resp.Body.Close()
				return nil, err
			}
			line = strings.TrimSpace(line)
			if !strings.HasPrefix(line, "data: ") {
				continue
			}
			data := strings.TrimPrefix(line, "data: ")

			var chunk struct {
				Candidates []struct {
					Content struct {
						Parts []geminiPart `json:"parts"`
					} `json:"content"`
				} `json:"candidates"`
			}
			if err := json.Unmarshal([]byte(data), &chunk); err != nil {
				continue
			}

			if len(chunk.Candidates) == 0 {
				continue
			}

			for _, part := range chunk.Candidates[0].Content.Parts {
				if part.Text != "" {
					out.Content += part.Text
					if textChunkChan != nil {
						textChunkChan <- part.Text
					}
				}
				if part.FunctionCall != nil {
					out.ToolCalls = append(out.ToolCalls, domain.ToolCall{
						ID:        fmt.Sprintf("call_%d", time.Now().UnixNano()),
						Name:      part.FunctionCall.Name,
						Arguments: part.FunctionCall.Args,
					})
				}
			}
		}

		resp.Body.Close()
		return out, nil
	}

	return nil, lastErr
}

func (g *GeminiProvider) buildRequest(systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) geminiRequest {
	var decls []geminiFunctionDecl
	for _, t := range tools {
		decls = append(decls, geminiFunctionDecl{
			Name:        t.Name,
			Description: t.Description,
			Parameters:  t.Parameters,
		})
	}

	var gemTools []geminiTool
	if len(decls) > 0 {
		gemTools = append(gemTools, geminiTool{FunctionDeclarations: decls})
	}

	var contents []geminiContent
	for _, m := range messages {
		if m.Role == "system" {
			continue
		}
		role := "user"
		if m.Role == "assistant" {
			role = "model"
		}

		var parts []geminiPart
		if m.Content != "" {
			parts = append(parts, geminiPart{Text: m.Content})
		}
		for _, tc := range m.ToolCalls {
			parts = append(parts, geminiPart{
				FunctionCall: &geminiFunctionCall{
					Name: tc.Name,
					Args: tc.Arguments,
				},
			})
		}
		contents = append(contents, geminiContent{
			Role:  role,
			Parts: parts,
		})
	}

	req := geminiRequest{
		Contents: contents,
		Tools:    gemTools,
	}

	if systemPrompt != "" {
		req.SystemInstruction = &geminiContent{
			Role:  "system",
			Parts: []geminiPart{{Text: systemPrompt}},
		}
	}

	return req
}

func uniqueStrings(slice []string) []string {
	seen := make(map[string]bool)
	var out []string
	for _, s := range slice {
		if s != "" && !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}
