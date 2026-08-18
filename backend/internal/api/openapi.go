package api

import (
	"github.com/danielgtaylor/huma/v2"
)

const (
	securityBearer = "bearerAuth"
)

func openAPIConfig() huma.Config {
	cfg := huma.DefaultConfig("Prumo API", "1.0.0")
	cfg.Info.Description = "API do ecossistema Prumo de Gestão Financeira Familiar com IA Agêntica."
	cfg.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		securityBearer: {
			Type:         "http",
			Scheme:       "bearer",
			BearerFormat: "JWT",
			Description:  "Token JWT emitido no login ou registro.",
		},
	}
	return cfg
}
