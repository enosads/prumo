package api

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
)

type HealthOutput struct {
	Body struct {
		Status  string `json:"status" example:"ok"`
		Version string `json:"version" example:"1.0.0"`
		Env     string `json:"env" example:"development"`
	}
}

func (s *Server) registerHealthRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "getHealth",
		Method:      http.MethodGet,
		Path:        "/health",
		Summary:     "Verificação de integridade da API",
		Tags:        []string{"Sistema"},
	}, func(ctx context.Context, input *struct{}) (*HealthOutput, error) {
		resp := &HealthOutput{}
		resp.Body.Status = "ok"
		resp.Body.Version = "1.0.0"
		resp.Body.Env = s.cfg.Env
		return resp, nil
	})
}
