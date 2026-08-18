package api

import (
	"context"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/auth"
)

type contextKey string

const (
	userContextKey contextKey = "user_claims"
)

type UserContext struct {
	UserID   uuid.UUID
	Email    string
	FamilyID *uuid.UUID
	Role     *string
}

func (s *Server) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			next.ServeHTTP(w, r)
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		claims, err := auth.ValidateToken(s.cfg.JWTSecret, tokenStr)
		if err != nil {
			next.ServeHTTP(w, r)
			return
		}

		uCtx := UserContext{
			UserID:   claims.UserID,
			Email:    claims.Email,
			FamilyID: claims.FamilyID,
			Role:     claims.Role,
		}

		ctx := context.WithValue(r.Context(), userContextKey, uCtx)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func requireAuth(ctx context.Context) (*UserContext, error) {
	val := ctx.Value(userContextKey)
	if val == nil {
		return nil, httpErrorUnauthorized("Não autenticado ou token inválido")
	}
	uCtx, ok := val.(UserContext)
	if !ok || uCtx.UserID == uuid.Nil {
		return nil, httpErrorUnauthorized("Sessão expirada ou inválida")
	}
	return &uCtx, nil
}

func requireFamily(ctx context.Context) (*UserContext, error) {
	uCtx, err := requireAuth(ctx)
	if err != nil {
		return nil, err
	}
	if uCtx.FamilyID == nil || *uCtx.FamilyID == uuid.Nil {
		return nil, httpErrorForbidden("Nenhum núcleo familiar selecionado")
	}
	return uCtx, nil
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s in %v", r.Method, r.URL.Path, time.Since(start))
	})
}

func recoverPanic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("[PANIC RECOVERED] %v", rec)
				http.Error(w, `{"error":"internal_server_error","message":"Ocorreu um erro interno"}`, http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}
