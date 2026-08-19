package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/internal/api"
	"github.com/enosads/prumo/backend/internal/config"
	"github.com/enosads/prumo/backend/internal/db"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

func main() {
	logger := log.New(os.Stdout, "[PRUMO-API] ", log.LstdFlags|log.Lshortfile)
	cfg := config.Load()

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	logger.Printf("Iniciando Prumo API no ambiente '%s'...", cfg.Env)

	// Aplica migrações embutidas automaticamente
	if err := db.Migrate(cfg.DatabaseURL); err != nil {
		logger.Fatalf("Falha ao aplicar migrações: %v", err)
	}
	logger.Println("Migrações aplicadas com sucesso.")

	// Conexão com o pool de conexões do PostgreSQL
	poolConfig, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		logger.Fatalf("Falha ao analisar DATABASE_URL: %v", err)
	}
	poolConfig.MaxConns = 25
	poolConfig.MinConns = 5

	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		logger.Fatalf("Falha ao conectar no PostgreSQL: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		logger.Fatalf("Não foi possível alcançar o banco de dados: %v", err)
	}
	logger.Println("Conexão com o PostgreSQL 18 estabelecida com sucesso.")

	queries := sqlc.New(pool)
	server := api.NewServer(cfg, queries, pool, logger)
	handler := server.Router()

	httpServer := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Printf("Servidor HTTP ouvindo na porta %s (Doc em http://localhost:%s/docs)", cfg.Port, cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("Erro crítico no servidor HTTP: %v", err)
		}
	}()

	<-ctx.Done()
	logger.Println("Sinal de encerramento recebido. Desligando com elegância...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		logger.Printf("Erro ao desligar o servidor HTTP: %v", err)
	}

	logger.Println("Servidor encerrado.")
}
