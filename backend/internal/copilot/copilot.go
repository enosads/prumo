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

	// 1. Provedor Anthropic Claude
	if cfg.AnthropicAPIKey != "" {
		providers = append(providers, llm.NewAnthropicProvider(cfg.AnthropicAPIKey, "claude-3-5-sonnet-20241022"))
	}

	// 2. Provedor OpenAI GPT-4o
	if cfg.OpenAIAPIKey != "" {
		providers = append(providers, llm.NewOpenAIProvider(cfg.OpenAIAPIKey, "gpt-4o"))
	}

	// 3. Provedor Google Gemini
	if cfg.GeminiAPIKey != "" {
		providers = append(providers, llm.NewGeminiProvider(cfg.GeminiAPIKey, "gemini-2.0-flash"))
	}

	// 4. Provedor Fallback / Mock sempre disponível
	providers = append(providers, llm.NewFallbackProvider())

	tools := app.NewToolRegistry(ledgerPort, creditPort, planningPort)
	tokenizer := pii.NewMemoryTokenizer()
	agent := app.NewCopilotAgent(providers, tools, tokenizer, queries)

	return app.NewCopilotService(agent, queries)
}
