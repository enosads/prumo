package api

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"github.com/enosads/prumo/backend/internal/auth"
	"github.com/enosads/prumo/backend/internal/authz"
	"github.com/enosads/prumo/backend/internal/db/sqlc"
)

type RegisterInput struct {
	Body struct {
		Email      string  `json:"email" format:"email" doc:"Endereço de e-mail do usuário"`
		FullName   string  `json:"full_name" minLength:"2" doc:"Nome completo"`
		Password   string  `json:"password" minLength:"6" doc:"Senha de acesso"`
		FamilyName *string `json:"family_name,omitempty" doc:"Nome do núcleo familiar inicial (opcional)"`
	}
}

type LoginInput struct {
	Body struct {
		Email    string `json:"email" format:"email" doc:"Endereço de e-mail"`
		Password string `json:"password" doc:"Senha"`
	}
}

type AuthUserJSON struct {
	ID        uuid.UUID  `json:"id"`
	Email     string     `json:"email"`
	FullName  string     `json:"full_name"`
	AvatarURL *string    `json:"avatar_url,omitempty"`
	FamilyID  *uuid.UUID `json:"family_id,omitempty"`
	Role      *string    `json:"role,omitempty"`
}

type AuthResponseOutput struct {
	Body struct {
		User         AuthUserJSON `json:"user"`
		AccessToken  string       `json:"access_token"`
		RefreshToken string       `json:"refresh_token"`
		ExpiresAt    time.Time    `json:"expires_at"`
	}
}

type MeOutput struct {
	Body struct {
		User     AuthUserJSON                   `json:"user"`
		Families []sqlc.ListFamiliesByUserIDRow `json:"families"`
	}
}

func (s *Server) registerAuthRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "registerUser",
		Method:      http.MethodPost,
		Path:        "/v1/auth/register",
		Summary:     "Cadastro de novo usuário com criação automática do núcleo familiar",
		Tags:        []string{"Autenticação"},
	}, func(ctx context.Context, input *RegisterInput) (*AuthResponseOutput, error) {
		// 1. Hash da senha
		hash, err := auth.HashPassword(input.Body.Password)
		if err != nil {
			return nil, httpErrorInternal("Erro ao processar senha")
		}

		// 2. Criação do usuário
		user, err := s.db.CreateUser(ctx, sqlc.CreateUserParams{
			Email:        input.Body.Email,
			FullName:     input.Body.FullName,
			PasswordHash: &hash,
		})
		if err != nil {
			return nil, httpErrorConflict("E-mail já cadastrado")
		}

		// 3. Criação do núcleo familiar padrão
		famName := fmt.Sprintf("Família de %s", input.Body.FullName)
		if input.Body.FamilyName != nil && *input.Body.FamilyName != "" {
			famName = *input.Body.FamilyName
		}

		family, err := s.db.CreateFamily(ctx, sqlc.CreateFamilyParams{
			Name:         famName,
			BaseCurrency: "BRL",
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar núcleo familiar")
		}

		// 4. Adiciona o usuário como owner da família
		roleOwner := authz.RoleOwner
		_, err = s.db.AddFamilyMember(ctx, sqlc.AddFamilyMemberParams{
			FamilyID: family.ID,
			UserID:   user.ID,
			Role:     roleOwner,
			Nickname: &input.Body.FullName,
		})
		if err != nil {
			return nil, httpErrorInternal("Erro ao vincular membro à família")
		}

		// 5. Geração de tokens
		accessToken, exp, err := auth.GenerateAccessToken(
			s.cfg.JWTSecret,
			user.ID,
			user.Email,
			&family.ID,
			&roleOwner,
			s.cfg.JWTExpirationHours,
		)
		if err != nil {
			return nil, httpErrorInternal("Erro ao emitir token de acesso")
		}

		refreshTokenStr, err := s.generateAndStoreRefreshToken(ctx, user.ID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar refresh token")
		}

		resp := &AuthResponseOutput{}
		resp.Body.User = AuthUserJSON{
			ID:        user.ID,
			Email:     user.Email,
			FullName:  user.FullName,
			AvatarURL: user.AvatarUrl,
			FamilyID:  &family.ID,
			Role:      &roleOwner,
		}
		resp.Body.AccessToken = accessToken
		resp.Body.RefreshToken = refreshTokenStr
		resp.Body.ExpiresAt = exp

		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "loginUser",
		Method:      http.MethodPost,
		Path:        "/v1/auth/login",
		Summary:     "Autenticação de usuário por e-mail e senha",
		Tags:        []string{"Autenticação"},
	}, func(ctx context.Context, input *LoginInput) (*AuthResponseOutput, error) {
		user, err := s.db.GetUserByEmail(ctx, input.Body.Email)
		if err != nil {
			return nil, httpErrorUnauthorized("E-mail ou senha inválidos")
		}

		if user.PasswordHash == nil || !auth.CheckPassword(input.Body.Password, *user.PasswordHash) {
			return nil, httpErrorUnauthorized("E-mail ou senha inválidos")
		}

		// Busca as famílias do usuário
		families, err := s.db.ListFamiliesByUserID(ctx, user.ID)
		var activeFamilyID *uuid.UUID
		var activeRole *string
		if err == nil && len(families) > 0 {
			activeFamilyID = &families[0].ID
			activeRole = &families[0].Role
		}

		accessToken, exp, err := auth.GenerateAccessToken(
			s.cfg.JWTSecret,
			user.ID,
			user.Email,
			activeFamilyID,
			activeRole,
			s.cfg.JWTExpirationHours,
		)
		if err != nil {
			return nil, httpErrorInternal("Erro ao emitir token de acesso")
		}

		refreshTokenStr, err := s.generateAndStoreRefreshToken(ctx, user.ID)
		if err != nil {
			return nil, httpErrorInternal("Erro ao criar refresh token")
		}

		resp := &AuthResponseOutput{}
		resp.Body.User = AuthUserJSON{
			ID:        user.ID,
			Email:     user.Email,
			FullName:  user.FullName,
			AvatarURL: user.AvatarUrl,
			FamilyID:  activeFamilyID,
			Role:      activeRole,
		}
		resp.Body.AccessToken = accessToken
		resp.Body.RefreshToken = refreshTokenStr
		resp.Body.ExpiresAt = exp

		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getMe",
		Method:      http.MethodGet,
		Path:        "/v1/auth/me",
		Summary:     "Dados do usuário logado e seus núcleos familiares",
		Tags:        []string{"Autenticação"},
		Security:    []map[string][]string{{securityBearer: {}}},
	}, func(ctx context.Context, input *struct{}) (*MeOutput, error) {
		uCtx, err := requireAuth(ctx)
		if err != nil {
			return nil, err
		}

		user, err := s.db.GetUserByID(ctx, uCtx.UserID)
		if err != nil {
			return nil, httpErrorNotFound("Usuário não encontrado")
		}

		families, err := s.db.ListFamiliesByUserID(ctx, user.ID)
		if err != nil {
			families = []sqlc.ListFamiliesByUserIDRow{}
		}

		resp := &MeOutput{}
		resp.Body.User = AuthUserJSON{
			ID:        user.ID,
			Email:     user.Email,
			FullName:  user.FullName,
			AvatarURL: user.AvatarUrl,
			FamilyID:  uCtx.FamilyID,
			Role:      uCtx.Role,
		}
		resp.Body.Families = families

		return resp, nil
	})
}

func (s *Server) generateAndStoreRefreshToken(ctx context.Context, userID uuid.UUID) (string, error) {
	rawBytes := make([]byte, 32)
	if _, err := rand.Read(rawBytes); err != nil {
		return "", err
	}
	rawToken := hex.EncodeToString(rawBytes)

	hash := sha256.Sum256([]byte(rawToken))
	tokenHash := hex.EncodeToString(hash[:])

	expiresAt := time.Now().Add(time.Duration(s.cfg.RefreshTokenExpirationDays) * 24 * time.Hour)
	_, err := s.db.CreateRefreshToken(ctx, sqlc.CreateRefreshTokenParams{
		UserID:    userID,
		TokenHash: tokenHash,
		ExpiresAt: expiresAt,
	})
	if err != nil {
		return "", err
	}

	return rawToken, nil
}
