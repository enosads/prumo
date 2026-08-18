package db

import (
	"context"
	"fmt"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/enosads/prumo/backend/migrations"
)

func NewPool(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("criando pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("conectando ao banco: %w", err)
	}
	return pool, nil
}

// Migrate aplica todas as migrations embutidas pendentes via advisory lock.
func Migrate(databaseURL string) error {
	src, err := iofs.New(migrations.FS, ".")
	if err != nil {
		return fmt.Errorf("lendo migrations embutidas: %w", err)
	}
	url := databaseURL
	for _, p := range []string{"postgresql://", "postgres://"} {
		if rest, ok := strings.CutPrefix(url, p); ok {
			url = "pgx5://" + rest
			break
		}
	}
	m, err := migrate.NewWithSourceInstance("iofs", src, url)
	if err != nil {
		return fmt.Errorf("preparando migração: %w", err)
	}
	defer m.Close()
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("aplicando migrations: %w", err)
	}
	return nil
}
