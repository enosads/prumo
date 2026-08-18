package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/enosads/prumo/backend/internal/db"
)

const dirPadrao = "internal/db/sqlc"

type consulta struct {
	local string
	nome  string
	sql   string
}

func main() {
	migrar := flag.Bool("migrate", false, "aplica as migrations antes de preparar")
	flag.Parse()

	url := os.Getenv("DATABASE_URL")
	if url == "" {
		fmt.Fprintln(os.Stderr, "sqlcprepare: DATABASE_URL vazia — use `make sqlc-prepare`")
		os.Exit(2)
	}

	if *migrar {
		if err := db.Migrate(url); err != nil {
			fmt.Fprintf(os.Stderr, "sqlcprepare: %v\n", err)
			os.Exit(2)
		}
	}

	consultas, err := extrair(dirPadrao)
	if err != nil {
		fmt.Fprintf(os.Stderr, "sqlcprepare: %v\n", err)
		os.Exit(2)
	}
	if len(consultas) == 0 {
		fmt.Fprintf(os.Stderr, "sqlcprepare: nenhuma consulta encontrada em %s\n", dirPadrao)
		os.Exit(2)
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "sqlcprepare: sem banco em %s (%v)\n", url, err)
		fmt.Fprintln(os.Stderr, "  suba com `make compose-up` e aplique o schema com `make migrate-up`")
		os.Exit(2)
	}
	defer conn.Close(ctx)

	var falhas int
	for _, c := range consultas {
		if _, err := conn.Prepare(ctx, c.nome, c.sql); err != nil {
			falhas++
			fmt.Printf("%s: %s\n    %s\n", c.local, c.nome, motivo(err))
		}
	}

	if falhas > 0 {
		fmt.Printf("\n%d de %d consultas foram recusadas pelo Postgres\n", falhas, len(consultas))
		os.Exit(1)
	}
	fmt.Printf("%d consultas preparadas, nenhuma recusada pelo PostgreSQL\n", len(consultas))
}

func motivo(err error) string {
	var pg *pgconn.PgError
	if !errors.As(err, &pg) {
		return err.Error()
	}
	m := fmt.Sprintf("%s: %s", pg.Code, pg.Message)
	if pg.Detail != "" {
		m += " (" + pg.Detail + ")"
	}
	return m
}

func extrair(dir string) ([]consulta, error) {
	arquivos, err := filepath.Glob(filepath.Join(dir, "*.sql.go"))
	if err != nil {
		return nil, err
	}

	fset := token.NewFileSet()
	var out []consulta
	for _, arquivo := range arquivos {
		f, err := parser.ParseFile(fset, arquivo, nil, 0)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", arquivo, err)
		}
		for _, d := range f.Decls {
			gen, ok := d.(*ast.GenDecl)
			if !ok || gen.Tok != token.CONST {
				continue
			}
			for _, s := range gen.Specs {
				vs, ok := s.(*ast.ValueSpec)
				if !ok || len(vs.Names) != 1 || len(vs.Values) != 1 {
					continue
				}
				sql, ok := texto(vs.Values[0])
				if !ok || !strings.Contains(sql, "-- name:") {
					continue
				}
				out = append(out, consulta{
					local: fmt.Sprintf("%s:%d", arquivo, fset.Position(vs.Pos()).Line),
					nome:  vs.Names[0].Name,
					sql:   sql,
				})
			}
		}
	}
	return out, nil
}

func texto(e ast.Expr) (string, bool) {
	switch v := e.(type) {
	case *ast.BasicLit:
		if v.Kind != token.STRING {
			return "", false
		}
		s, err := strconv.Unquote(v.Value)
		return s, err == nil
	case *ast.BinaryExpr:
		if v.Op != token.ADD {
			return "", false
		}
		esq, ok := texto(v.X)
		if !ok {
			return "", false
		}
		dir, ok := texto(v.Y)
		if !ok {
			return "", false
		}
		return esq + dir, true
	}
	return "", false
}
