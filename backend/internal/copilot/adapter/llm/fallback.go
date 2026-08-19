package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/enosads/prumo/backend/internal/copilot/domain"
)

type FallbackProvider struct{}

func NewFallbackProvider() *FallbackProvider {
	return &FallbackProvider{}
}

func (f *FallbackProvider) Name() string {
	return "fallback_mock"
}

func (f *FallbackProvider) Chat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition) (*LLMResponse, error) {
	return f.generate(ctx, messages, tools, nil)
}

func (f *FallbackProvider) StreamChat(ctx context.Context, systemPrompt string, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error) {
	return f.generate(ctx, messages, tools, textChunkChan)
}

func (f *FallbackProvider) generate(ctx context.Context, messages []LLMMessage, tools []domain.ToolDefinition, textChunkChan chan<- string) (*LLMResponse, error) {
	if len(messages) == 0 {
		return &LLMResponse{Content: "Olá! Sou o Copilot do Prumo. Como posso ajudar com as finanças da sua família hoje?"}, nil
	}

	lastMsg := messages[len(messages)-1]

	// Verifica se a última mensagem é o resultado de uma Tool executada
	if lastMsg.Role == "tool" || lastMsg.ToolCallID != nil || hasToolResults(messages) {
		summaryText := f.synthesizeToolResults(messages)
		f.streamString(summaryText, textChunkChan)
		return &LLMResponse{Content: summaryText}, nil
	}

	// Análise de intenção da mensagem do usuário para chamar Tools
	userText := strings.ToLower(lastMsg.Content)

	if strings.Contains(userText, "patrimônio") || strings.Contains(userText, "saldo") || strings.Contains(userText, "consolidado") || strings.Contains(userText, "contas") {
		return &LLMResponse{
			ToolCalls: []domain.ToolCall{
				{
					ID:        fmt.Sprintf("call_nw_%d", time.Now().UnixNano()),
					Name:      "get_consolidated_net_worth",
					Arguments: json.RawMessage(`{}`),
				},
			},
		}, nil
	}

	if strings.Contains(userText, "gastei") || strings.Contains(userText, "extrato") || strings.Contains(userText, "alimentação") || strings.Contains(userText, "mercado") || strings.Contains(userText, "despesa") || strings.Contains(userText, "transaç") {
		args := `{}`
		if strings.Contains(userText, "alimentação") || strings.Contains(userText, "mercado") || strings.Contains(userText, "comida") {
			args = `{"category_slug":"food"}`
		}
		return &LLMResponse{
			ToolCalls: []domain.ToolCall{
				{
					ID:        fmt.Sprintf("call_cf_%d", time.Now().UnixNano()),
					Name:      "query_cash_flow",
					Arguments: json.RawMessage(args),
				},
			},
		}, nil
	}

	if strings.Contains(userText, "orçamento") || strings.Contains(userText, "envelope") || strings.Contains(userText, "livre para investir") || strings.Contains(userText, "limite") {
		return &LLMResponse{
			ToolCalls: []domain.ToolCall{
				{
					ID:        fmt.Sprintf("call_bg_%d", time.Now().UnixNano()),
					Name:      "get_budget_status",
					Arguments: json.RawMessage(`{}`),
				},
			},
		}, nil
	}

	if strings.Contains(userText, "fatura") || strings.Contains(userText, "cartão") || strings.Contains(userText, "cartao") || strings.Contains(userText, "parcela") || strings.Contains(userText, "projeção") {
		return &LLMResponse{
			ToolCalls: []domain.ToolCall{
				{
					ID:        fmt.Sprintf("call_cp_%d", time.Now().UnixNano()),
					Name:      "get_card_projections",
					Arguments: json.RawMessage(`{"months_ahead":12}`),
				},
			},
		}, nil
	}

	// Resposta conversacional padrão
	respText := "Olá! Sou o **Copilot do Prumo**, seu assistente financeiro familiar com IA nativa.\n\nPosso ajudar você a:\n- 📊 **Consultar Patrimônio Líquido** consolidado e por conta\n- 🧾 **Analisar Extrato & Gastos** por período e categoria\n- 🎯 **Acompanhar Envelopes de Orçamento** e valor 'Livre para Investir'\n- 💳 **Projetar Faturas e Parcelas** futuras de cartões de crédito\n\nComo posso ajudar agora?"
	f.streamString(respText, textChunkChan)
	return &LLMResponse{Content: respText}, nil
}

func (f *FallbackProvider) streamString(text string, textChunkChan chan<- string) {
	if textChunkChan == nil {
		return
	}
	words := strings.Split(text, " ")
	for i, w := range words {
		suffix := " "
		if i == len(words)-1 {
			suffix = ""
		}
		textChunkChan <- w + suffix
	}
}

func hasToolResults(messages []LLMMessage) bool {
	for _, m := range messages {
		if m.Role == "tool" || m.ToolCallID != nil {
			return true
		}
	}
	return false
}

func (f *FallbackProvider) synthesizeToolResults(messages []LLMMessage) string {
	var toolResults []string
	for _, m := range messages {
		if m.Role == "tool" || m.ToolCallID != nil {
			toolResults = append(toolResults, m.Content)
		}
	}

	joined := strings.Join(toolResults, "\n")
	lowerJoined := strings.ToLower(joined)

	// Síntese de Patrimônio
	if strings.Contains(lowerJoined, "total_net_worth_cents") || strings.Contains(lowerJoined, "totalnetworthcents") || strings.Contains(lowerJoined, "checking_cents") || strings.Contains(lowerJoined, "checkingcents") {
		var data struct {
			TotalNetWorthCents int64 `json:"total_net_worth_cents"`
			CheckingCents      int64 `json:"checking_cents"`
			SavingsCents       int64 `json:"savings_cents"`
			InvestmentCents    int64 `json:"investment_cents"`
		}
		_ = json.Unmarshal([]byte(joined), &data)
		return fmt.Sprintf("📊 **Patrimônio Líquido Consolidado da Família**\n\n- **Total Líquido**: R$ %.2f\n- **Conta Corrente**: R$ %.2f\n- **Reserva / Poupança**: R$ %.2f\n- **Investimentos**: R$ %.2f\n\nTodos os saldos estão atualizados.",
			float64(data.TotalNetWorthCents)/100.0,
			float64(data.CheckingCents)/100.0,
			float64(data.SavingsCents)/100.0,
			float64(data.InvestmentCents)/100.0,
		)
	}

	// Síntese de Fluxo de Caixa / Extrato
	if strings.Contains(lowerJoined, "total_income_cents") || strings.Contains(lowerJoined, "totalincomecents") || strings.Contains(lowerJoined, "netcashflowcents") || strings.Contains(lowerJoined, "net_cash_flow_cents") {
		return "🧾 **Extrato & Fluxo de Caixa Consultado**\n\nAnalisei as movimentações solicitadas no seu livro-razão. Os lançamentos foram recuperados com sucesso e estão refletidos nos cálculos de saldo e orçamentos."
	}

	// Síntese de Orçamento
	if strings.Contains(lowerJoined, "free_to_invest_cents") || strings.Contains(lowerJoined, "freetoinvestcents") || strings.Contains(lowerJoined, "total_budgeted_cents") || strings.Contains(lowerJoined, "totalbudgetedcents") {
		return "🎯 **Status dos Envelopes de Orçamento**\n\nSeus envelopes orçamentários foram analisados. O valor **Livre para Investir** está calculado e pronto para destinação estratégica familiar."
	}

	// Síntese de Cartões
	if strings.Contains(lowerJoined, "used_limit_cents") || strings.Contains(lowerJoined, "usedlimitcents") || strings.Contains(lowerJoined, "projections") {
		return "💳 **Projeção de Faturas de Cartão**\n\nConsultei os limites e parcelas futuras dos seus cartões de crédito para os próximos meses. Os valores estão organizados por vencimento."
	}

	return "✅ Consulta realizada com sucesso! As informações financeiras foram recuperadas do seu núcleo familiar."
}
