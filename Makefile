GO     ?= go
GOBIN  ?= $(shell $(GO) env GOPATH)/bin

# Porta 5434 para isolamento e evitar conflitos locais com outros projetos.
DATABASE_URL ?= postgres://prumo:prumo@localhost:5434/prumo?sslmode=disable

.PHONY: help be-build be-test be-run be-lint be-fmt be-tidy sqlc-gen \
        compose-up compose-down migrate-up migrate-down migrate-create smoke \
        sqlc-prepare api-spec ios-gen ios-build ios-test

help:
	@echo "Backend:"
	@echo "  make compose-up       - sobe Postgres 18 (porta 5434) e Redis via docker compose"
	@echo "  make compose-down     - para os containers (mantém volumes)"
	@echo "  make migrate-up       - aplica migrations pendentes"
	@echo "  make migrate-down     - reverte a última migration"
	@echo "  make migrate-create name=<nome> - cria par .up/.down.sql"
	@echo "  make sqlc-gen         - regenera o código do sqlc"
	@echo "  make sqlc-prepare     - valida todas as queries geradas contra o Postgres"
	@echo "  make be-build         - compila o backend"
	@echo "  make be-test          - testes unitários e de integração com race detector"
	@echo "  make be-run           - roda o servidor HTTP da API (porta 8085)"
	@echo "  make api-spec         - exporta a especificação OpenAPI 3.0 para backend/openapi.json"
	@echo "  make be-lint          - golangci-lint"
	@echo "  make be-fmt           - formata o código Go com gofumpt"
	@echo "  make smoke            - executa o smoke test E2E da API"
	@echo "iOS:"
	@echo "  make ios-gen          - gera o .xcodeproj via XcodeGen"
	@echo "  make ios-build        - compila o app para o simulador iOS"
	@echo "  make ios-test         - executa os testes do app no simulador"

compose-up:
	cd backend && docker compose up -d

compose-down:
	cd backend && docker compose down

migrate-up:
	$(GOBIN)/migrate -path backend/migrations -database "$(DATABASE_URL)" up

migrate-down:
	$(GOBIN)/migrate -path backend/migrations -database "$(DATABASE_URL)" down 1

migrate-create:
	@test -n "$(name)" || (echo "uso: make migrate-create name=<nome_descritivo>" && exit 1)
	$(GOBIN)/migrate create -ext sql -dir backend/migrations -seq -digits 4 $(name)

sqlc-gen:
	cd backend && sqlc generate

sqlc-prepare:
	cd backend && DATABASE_URL="$(DATABASE_URL)" $(GO) run ./cmd/sqlcprepare

be-build:
	cd backend && $(GO) build ./...

be-test:
	cd backend && $(GO) test ./... -race

be-run:
	cd backend && $(GO) run ./cmd/server

be-lint:
	cd backend && $(GOBIN)/golangci-lint run

be-fmt:
	cd backend && $(GOBIN)/gofumpt -l -w .

be-tidy:
	cd backend && $(GO) mod tidy

smoke:
	./scripts/smoke.sh

api-spec:
	curl -s http://localhost:8085/openapi.json | python3 -m json.tool > backend/openapi.json
	@echo "spec salva em backend/openapi.json"

ios-gen:
	cd ios && xcodegen generate

ios-build: ios-gen
	cd ios && xcodebuild -project Prumo.xcodeproj -scheme Prumo \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath DerivedData \
		CODE_SIGNING_ALLOWED=NO build

ios-test: ios-gen
	cd ios && xcodebuild -project Prumo.xcodeproj -scheme Prumo \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-derivedDataPath DerivedData \
		CODE_SIGNING_ALLOWED=NO test
