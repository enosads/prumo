package api

import (
	"net/http"

	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func (s *Server) Router() http.Handler {
	r := chi.NewRouter()

	// Middlewares globais
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(recoverPanic)
	r.Use(logRequests)
	r.Use(s.authMiddleware)

	// Inicializa o adaptador OpenAPI Huma v2 com Chi
	api := humachi.New(r, openAPIConfig())

	// Registra os módulos de rotas
	s.registerHealthRoutes(api)
	s.registerAuthRoutes(api)
	s.registerFamilyRoutes(api)
	s.registerAccountRoutes(api)

	return r
}
