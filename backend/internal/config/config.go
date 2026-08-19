package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port                       string
	Env                        string
	BaseURL                    string
	DatabaseURL                string
	RedisURL                   string
	JWTSecret                  string
	JWTExpirationHours         int
	RefreshTokenExpirationDays int
	AnthropicAPIKey            string
	OpenAIAPIKey               string
	GeminiAPIKey               string
	GeminiModel                string
	APNSKeyID                  string
	APNSTeamID                 string
	APNSBundleID               string
	APNSKeyBase64              string
}

func Load() *Config {
	return &Config{
		Port:                       getEnv("PORT", "8085"),
		Env:                        getEnv("ENV", "development"),
		BaseURL:                    getEnv("BASE_URL", "http://localhost:8085"),
		DatabaseURL:                getEnv("DATABASE_URL", "postgres://prumo:prumo@localhost:5434/prumo?sslmode=disable"),
		RedisURL:                   getEnv("REDIS_URL", "redis://localhost:6380/0"),
		JWTSecret:                  getEnv("JWT_SECRET", "prumo-dev-super-secret-jwt-key-minimum-32-chars-long-here"),
		JWTExpirationHours:         getEnvAsInt("JWT_EXPIRATION_HOURS", 24),
		RefreshTokenExpirationDays: getEnvAsInt("REFRESH_TOKEN_EXPIRATION_DAYS", 30),
		AnthropicAPIKey:            os.Getenv("ANTHROPIC_API_KEY"),
		OpenAIAPIKey:               os.Getenv("OPENAI_API_KEY"),
		GeminiAPIKey:               os.Getenv("GEMINI_API_KEY"),
		GeminiModel:                getEnv("GEMINI_MODEL", "gemini-2.5-flash"),
		APNSKeyID:                  os.Getenv("APNS_KEY_ID"),
		APNSTeamID:                 os.Getenv("APNS_TEAM_ID"),
		APNSBundleID:               getEnv("APNS_BUNDLE_ID", "dev.enosads.prumo"),
		APNSKeyBase64:              os.Getenv("APNS_KEY_BASE64"),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvAsInt(key string, fallback int) int {
	valStr := os.Getenv(key)
	if valStr == "" {
		return fallback
	}
	val, err := strconv.Atoi(valStr)
	if err != nil {
		return fallback
	}
	return val
}
