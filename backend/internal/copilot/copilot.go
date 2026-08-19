package copilot

import (
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/config"
	"github.com/enosads/prumo/backend/internal/copilot/adapter/llm"
	"github.com/enosads/prumo/backend/internal/copilot/app"
	"github.com/enosads/prumo/backend/internal/copilot/domain"
	creditDomain "github.com/enosads/prumo/backend/internal/credit/domain"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
	ledgerDomain "github.com/enosads/prumo/backend/internal/ledger/domain"
	planningDomain "github.com/enosads/prumo/backend/internal/planning/domain"
	"github.com/enosads/prumo/backend/pkg/pii"
)

func NewCopilot(
	cfg *config.Config,
	queries *sqlc.Queries,
	pool *pgxpool.Pool,
	ledgerPort ledgerDomain.LedgerPort,
	creditPort creditDomain.CreditPort,
	planningPort planningDomain.PlanningPort,
) domain.CopilotPort {
	var providers []llm.LLMProvider

	// 1. Provedor Google Gemini (Versão mais recente Flash)
	if cfg.GeminiAPIKey != "" {
		gemModel := cfg.GeminiModel
		if gemModel == "" {
			gemModel = "gemini-2.5-flash"
		}
		providers = append(providers, llm.NewGeminiProvider(cfg.GeminiAPIKey, gemModel))
	}

	// 2. Provedor Anthropic Claude
	if cfg.AnthropicAPIKey != "" {
		anthModel := cfg.AnthropicModel
		if anthModel == "" {
			anthModel = "claude-3-7-sonnet-20250219"
		}
		providers = append(providers, llm.NewAnthropicProvider(cfg.AnthropicAPIKey, anthModel))
	}

	// 3. Provedor OpenAI GPT-4o
	if cfg.OpenAIAPIKey != "" {
		providers = append(providers, llm.NewOpenAIProvider(cfg.OpenAIAPIKey, "gpt-4o"))
	}

	// 4. Provedor Fallback / Mock sempre disponível
	providers = append(providers, llm.NewFallbackProvider())

	tools := app.NewToolRegistry(ledgerPort, creditPort, planningPort)
	tokenizer := pii.NewMemoryTokenizer()
	agent := app.NewCopilotAgent(providers, tools, tokenizer, queries)

	return app.NewCopilotService(agent, queries)
}
