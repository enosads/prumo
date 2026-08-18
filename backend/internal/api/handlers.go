package api

import (
	"log"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/config"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type Server struct {
	cfg  *config.Config
	db   *sqlc.Queries
	pool *pgxpool.Pool
	log  *log.Logger
}

func NewServer(cfg *config.Config, db *sqlc.Queries, pool *pgxpool.Pool, logger *log.Logger) *Server {
	return &Server{
		cfg:  cfg,
		db:   db,
		pool: pool,
		log:  logger,
	}
}
