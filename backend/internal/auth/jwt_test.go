package auth

import (
	"testing"

	"github.com/google/uuid"
)

func TestJWTGenerationAndValidation(t *testing.T) {
	secret := "test-jwt-secret-key-32-characters-minimum"
	userID := uuid.New()
	email := "teste@prumo.app"
	familyID := uuid.New()
	role := "owner"

	tokenStr, exp, err := GenerateAccessToken(secret, userID, email, &familyID, &role, 2)
	if err != nil {
		t.Fatalf("falha ao gerar token: %v", err)
	}

	if tokenStr == "" {
		t.Fatal("token gerado está vazio")
	}

	if exp.IsZero() {
		t.Fatal("data de expiração inválida")
	}

	claims, err := ValidateToken(secret, tokenStr)
	if err != nil {
		t.Fatalf("falha ao validar token: %v", err)
	}

	if claims.UserID != userID {
		t.Errorf("esperava userID %s, obteve %s", userID, claims.UserID)
	}

	if claims.Email != email {
		t.Errorf("esperava email %s, obteve %s", email, claims.Email)
	}

	if claims.FamilyID == nil || *claims.FamilyID != familyID {
		t.Errorf("esperava familyID %s, obteve %v", familyID, claims.FamilyID)
	}

	if claims.Role == nil || *claims.Role != role {
		t.Errorf("esperava role %s, obteve %v", role, claims.Role)
	}
}

func TestJWTInvalidSecret(t *testing.T) {
	secret1 := "secret-one-32-characters-long-key-abc"
	secret2 := "secret-two-32-characters-long-key-xyz"
	userID := uuid.New()
	email := "teste2@prumo.app"

	tokenStr, _, err := GenerateAccessToken(secret1, userID, email, nil, nil, 1)
	if err != nil {
		t.Fatalf("falha ao gerar token: %v", err)
	}

	_, err = ValidateToken(secret2, tokenStr)
	if err == nil {
		t.Fatal("esperava erro de assinatura inválida com secret diferente")
	}
}
