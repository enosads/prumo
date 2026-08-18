#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Smoke Test E2E do Prumo
# ============================================================================

BASE_URL="${BASE_URL:-http://localhost:8085}"
RAND_SUFFIX=$(date +%s%N | tail -c 6)
TEST_EMAIL="smoke_test_${RAND_SUFFIX}@prumo.app"
TEST_PASS="Prumo#Secure2026"
TEST_NAME="Casal Teste ${RAND_SUFFIX}"

echo "=================================================="
echo "Iniciando Smoke Test E2E contra ${BASE_URL}"
echo "=================================================="

# 1. Healthcheck
echo -n "1. Verificando /health... "
HEALTH_RESP=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health")
HTTP_CODE=$(echo "${HEALTH_RESP}" | tail -n1)
BODY=$(echo "${HEALTH_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 2. Cadastro de Usuário e Família
echo -n "2. Registrando novo usuário (${TEST_EMAIL})... "
REGISTER_PAYLOAD=$(cat <<EOF
{
  "email": "${TEST_EMAIL}",
  "full_name": "${TEST_NAME}",
  "password": "${TEST_PASS}",
  "family_name": "Família Silva"
}
EOF
)

REG_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d "${REGISTER_PAYLOAD}")

HTTP_CODE=$(echo "${REG_RESP}" | tail -n1)
BODY=$(echo "${REG_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi

ACCESS_TOKEN=$(echo "${BODY}" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
FAMILY_ID=$(echo "${BODY}" | grep -o '"family_id":"[^"]*' | cut -d'"' -f4)
USER_ID=$(echo "${BODY}" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)

if [ -z "${ACCESS_TOKEN}" ] || [ -z "${FAMILY_ID}" ]; then
    echo "FALHOU: Token ou Family ID não retornado"
    echo "${BODY}"
    exit 1
fi
echo "OK (Family ID: ${FAMILY_ID})"

# 3. Login
echo -n "3. Efetuando login com credenciais... "
LOGIN_PAYLOAD=$(cat <<EOF
{
  "email": "${TEST_EMAIL}",
  "password": "${TEST_PASS}"
}
EOF
)

LOGIN_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}")

HTTP_CODE=$(echo "${LOGIN_RESP}" | tail -n1)
BODY=$(echo "${LOGIN_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 4. Consulta de Perfil (/v1/auth/me)
echo -n "4. Consultando /v1/auth/me... "
ME_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/auth/me" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

HTTP_CODE=$(echo "${ME_RESP}" | tail -n1)
BODY=$(echo "${ME_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 5. Listar Membros da Família
echo -n "5. Listando membros da família... "
MEMBERS_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/families/${FAMILY_ID}/members" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

HTTP_CODE=$(echo "${MEMBERS_RESP}" | tail -n1)
BODY=$(echo "${MEMBERS_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 6. Criar Convite Familiar
echo -n "6. Gerando convite para parceiro(a)... "
INVITE_PAYLOAD=$(cat <<EOF
{
  "email": "partner_${RAND_SUFFIX}@prumo.app",
  "role": "admin"
}
EOF
)

INVITE_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/families/${FAMILY_ID}/invitations" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${INVITE_PAYLOAD}")

HTTP_CODE=$(echo "${INVITE_RESP}" | tail -n1)
BODY=$(echo "${INVITE_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 7. Criar Conta Financeira
echo -n "7. Criando conta corrente familiar... "
ACCOUNT_PAYLOAD=$(cat <<EOF
{
  "name": "Nubank Principal",
  "kind": "checking",
  "visibility": "shared",
  "currency": "BRL",
  "initial_balance_cents": 250000,
  "color": "#820AD1"
}
EOF
)

ACC_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/accounts" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${ACCOUNT_PAYLOAD}")

HTTP_CODE=$(echo "${ACC_RESP}" | tail -n1)
BODY=$(echo "${ACC_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 8. Listar Contas
echo -n "8. Listando contas cadastradas... "
LIST_ACC_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/accounts" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

HTTP_CODE=$(echo "${LIST_ACC_RESP}" | tail -n1)
BODY=$(echo "${LIST_ACC_RESP}" | sed '$d')

if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 9. Testes de Sabotagem (Segurança e Validação)
echo -n "9. Teste de Sabotagem: acesso sem token (deve ser 401)... "
SAB1_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/accounts")
HTTP_CODE=$(echo "${SAB1_RESP}" | tail -n1)
if [ "${HTTP_CODE}" -ne 401 ]; then
    echo "FALHOU (Esperava 401, recebeu ${HTTP_CODE})"
    exit 1
fi
echo "OK (401)"

echo -n "10. Teste de Sabotagem: acesso a família alheia (deve ser 403)... "
SAB2_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/families/00000000-0000-0000-0000-000000000000/members" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${SAB2_RESP}" | tail -n1)
if [ "${HTTP_CODE}" -ne 403 ]; then
    echo "FALHOU (Esperava 403, recebeu ${HTTP_CODE})"
    exit 1
fi
echo "OK (403)"

echo "=================================================="
echo "🎉 TODOS OS SMOKE TESTS PASSARAM COM SUCESSO!"
echo "=================================================="
