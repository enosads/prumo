package api

import (
	"log"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/config"
	"github.com/enosads/prumo/backend/internal/copilot"
	copilotDomain "github.com/enosads/prumo/backend/internal/copilot/domain"
	creditApp "github.com/enosads/prumo/backend/internal/credit/app"
	creditDomain "github.com/enosads/prumo/backend/internal/credit/domain"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
	ledgerApp "github.com/enosads/prumo/backend/internal/ledger/app"
	ledgerDomain "github.com/enosads/prumo/backend/internal/ledger/domain"
	planningApp "github.com/enosads/prumo/backend/internal/planning/app"
	planningDomain "github.com/enosads/prumo/backend/internal/planning/domain"
)

type Server struct {
	cfg      *config.Config
	db       *sqlc.Queries
	pool     *pgxpool.Pool
	log      *log.Logger
	ledger   ledgerDomain.LedgerPort
	credit   creditDomain.CreditPort
	planning planningDomain.PlanningPort
	copilot  copilotDomain.CopilotPort
}

func NewServer(cfg *config.Config, db *sqlc.Queries, pool *pgxpool.Pool, logger *log.Logger) *Server {
	ledgerSvc := ledgerApp.NewLedgerService(db, pool)
	creditSvc := creditApp.NewCreditService(db, pool)
	planningSvc := planningApp.NewPlanningService(db, pool)
	copilotSvc := copilot.NewCopilot(cfg, db, pool, ledgerSvc, creditSvc, planningSvc)

	return &Server{
		cfg:      cfg,
		db:       db,
		pool:     pool,
		log:      logger,
		ledger:   ledgerSvc,
		credit:   creditSvc,
		planning: planningSvc,
		copilot:  copilotSvc,
	}
}
