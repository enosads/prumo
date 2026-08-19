#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Smoke Test E2E do Prumo
# ============================================================================

BASE_URL="${BASE_URL:-http://localhost:8085}"
RAND_SUFFIX="$(date +%s)_$RANDOM"
TEST_EMAIL="smoke_${RAND_SUFFIX}@prumo.app"
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
USER_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)

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

# ============================================================================
# FASE 1: FATIA 1.1 — CATEGORIAS E TRANSAÇÕES
# ============================================================================

# 11. Listar e Auto-Seed de Categorias
echo -n "11. Listando categorias (auto-seed padrão)... "
CATS_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/categories" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${CATS_RESP}" | tail -n1)
BODY=$(echo "${CATS_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
CAT_FOOD_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
echo "OK (Categoria Food ID: ${CAT_FOOD_ID})"

# 12. Criar Categoria Customizada
echo -n "12. Criando categoria customizada (Pets & Veterinário)... "
CAT_PAYLOAD=$(cat <<EOF
{
  "name": "Pets & Veterinário",
  "icon": "pawprint.fill",
  "color": "#FF6B6B",
  "kind": "expense"
}
EOF
)
NEW_CAT_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/categories" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CAT_PAYLOAD}")
HTTP_CODE=$(echo "${NEW_CAT_RESP}" | tail -n1)
BODY=$(echo "${NEW_CAT_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
PET_CAT_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | cut -d'"' -f4)
echo "OK (Pet Cat ID: ${PET_CAT_ID})"

# 13. Criar Transação de Receita (Salário)
ACCOUNT_ID=$(echo "${ACC_RESP}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
echo -n "13. Lançando receita (Salário R$ 8.000,00)... "
INC_PAYLOAD=$(cat <<EOF
{
  "account_id": "${ACCOUNT_ID}",
  "kind": "income",
  "amount_cents": 800000,
  "description": "Salário Mensal",
  "tags": ["salario", "trabalho"]
}
EOF
)
INC_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/transactions" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${INC_PAYLOAD}")
HTTP_CODE=$(echo "${INC_RESP}" | tail -n1)
BODY=$(echo "${INC_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 14. Criar Transação de Despesa (Supermercado)
echo -n "14. Lançando despesa (Supermercado R$ 450,00)... "
EXP_PAYLOAD=$(cat <<EOF
{
  "account_id": "${ACCOUNT_ID}",
  "category_id": "${CAT_FOOD_ID}",
  "kind": "expense",
  "amount_cents": 45000,
  "description": "Compras do Mês - Mercado",
  "tags": ["mercado", "comida"]
}
EOF
)
EXP_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/transactions" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${EXP_PAYLOAD}")
HTTP_CODE=$(echo "${EXP_RESP}" | tail -n1)
BODY=$(echo "${EXP_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 15. Criar Conta Poupança e Efetuar Transferência entre Contas
echo -n "15. Criando conta poupança e transferindo R$ 1.500,00... "
SAVINGS_PAYLOAD=$(cat <<EOF
{
  "name": "Reserva de Emergência",
  "kind": "savings",
  "visibility": "shared",
  "currency": "BRL",
  "initial_balance_cents": 0,
  "color": "#30B0C7"
}
EOF
)
SAV_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/accounts" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${SAVINGS_PAYLOAD}")
SAV_ACC_ID=$(echo "${SAV_RESP}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)

TRANS_PAYLOAD=$(cat <<EOF
{
  "account_id": "${ACCOUNT_ID}",
  "destination_account_id": "${SAV_ACC_ID}",
  "kind": "transfer",
  "amount_cents": 150000,
  "description": "Aporte na Reserva de Emergência"
}
EOF
)
TRANS_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/transactions" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${TRANS_PAYLOAD}")
HTTP_CODE=$(echo "${TRANS_RESP}" | tail -n1)
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    exit 1
fi
echo "OK"

# 16. Listar Transações com Filtros
echo -n "16. Consultando extrato com filtros... "
TX_LIST_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/transactions?kind=expense" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${TX_LIST_RESP}" | tail -n1)
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    exit 1
fi
echo "OK"

# ============================================================================
# FASE 1: FATIA 1.2 — CARTÕES, FATURAS, PARCELAS E ANTECIPAÇÃO
# ============================================================================

# 17. Criar Cartão de Crédito
echo -n "17. Cadastrando Cartão de Crédito (Limite R$ 10.000,00)... "
CARD_PAYLOAD=$(cat <<EOF
{
  "name": "Nubank Ultravioleta",
  "last_four_digits": "9876",
  "credit_limit_cents": 1000000,
  "closing_day": 10,
  "due_day": 17,
  "color": "#820AD1"
}
EOF
)
CARD_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/cards" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CARD_PAYLOAD}")
HTTP_CODE=$(echo "${CARD_RESP}" | tail -n1)
BODY=$(echo "${CARD_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
CARD_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
CARD_ACC_ID=$(echo "${BODY}" | grep -oiE '"(account_id|accountid)":"[^"]*' | head -n1 | cut -d'"' -f4)
echo "OK (Card ID: ${CARD_ID})"

# 18. Lançar Compra Parcelada em 3x no Cartão
echo -n "18. Lançando compra parcelada em 3x (R$ 900,00 total)... "
INSTALLMENT_PAYLOAD=$(cat <<EOF
{
  "account_id": "${CARD_ACC_ID}",
  "category_id": "${CAT_FOOD_ID}",
  "kind": "expense",
  "amount_cents": 90000,
  "description": "Supermercado Grande 3x",
  "installment_total": 3
}
EOF
)
INST_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/transactions" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${INSTALLMENT_PAYLOAD}")
HTTP_CODE=$(echo "${INST_RESP}" | tail -n1)
BODY=$(echo "${INST_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 19. Consultar Projeção de Parcelas para os Próximos 12 Meses
echo -n "19. Consultando projeção de faturas dos próximos 12 meses... "
PROJ_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/cards/${CARD_ID}/installments" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${PROJ_RESP}" | tail -n1)
BODY=$(echo "${PROJ_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
FUTURE_TX_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | tail -n1 | cut -d'"' -f4)
echo "OK"

# 20. Simular Antecipação de Parcelas com Desconto
echo -n "20. Simulando antecipação de parcela futura com desconto... "
SIM_PAYLOAD=$(cat <<EOF
{
  "transaction_ids": ["${FUTURE_TX_ID}"],
  "annual_discount_rate": 12.5
}
EOF
)
SIM_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/cards/${CARD_ID}/installments/anticipate/simulate" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${SIM_PAYLOAD}")
HTTP_CODE=$(echo "${SIM_RESP}" | tail -n1)
BODY=$(echo "${SIM_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 21. Aplicar Antecipação de Parcelas
echo -n "21. Efetivando antecipação para a fatura atual... "
APPLY_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/cards/${CARD_ID}/installments/anticipate/apply" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${SIM_PAYLOAD}")
HTTP_CODE=$(echo "${APPLY_RESP}" | tail -n1)
BODY=$(echo "${APPLY_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
INVOICE_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
echo "OK (Fatura Atual ID: ${INVOICE_ID})"

# 22. Pagar Fatura de Cartão de Crédito
echo -n "22. Pagando fatura do cartão com conta corrente... "
PAY_INV_PAYLOAD=$(cat <<EOF
{
  "payment_account_id": "${ACCOUNT_ID}",
  "amount_cents": 10000
}
EOF
)
PAY_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/cards/${CARD_ID}/invoices/${INVOICE_ID}/pay" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PAY_INV_PAYLOAD}")
HTTP_CODE=$(echo "${PAY_RESP}" | tail -n1)
BODY=$(echo "${PAY_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# ============================================================================
# FASE 1: FATIA 1.3 — ORÇAMENTOS POR ENVELOPE & LIVRE PARA INVESTIR
# ============================================================================

# 23. Consultar Orçamento do Mês
echo -n "23. Consultando orçamento mensal da família... "
BUDGET_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/budgets" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${BUDGET_RESP}" | tail -n1)
BODY=$(echo "${BUDGET_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
BUDGET_ID=$(echo "${BODY}" | grep -oi '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
echo "OK (Budget ID: ${BUDGET_ID})"

# 24. Definir Teto de Envelope de Categoria
echo -n "24. Definindo teto de envelope para Alimentação (R$ 1.200,00)... "
ITEM_PAYLOAD=$(cat <<EOF
{
  "category_id": "${CAT_FOOD_ID}",
  "allocated_amount_cents": 120000,
  "rollover_enabled": true
}
EOF
)
ITEM_RESP=$(curl -s -w "\n%{http_code}" -X PUT "${BASE_URL}/v1/budgets/${BUDGET_ID}/items" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${ITEM_PAYLOAD}")
HTTP_CODE=$(echo "${ITEM_RESP}" | tail -n1)
BODY=$(echo "${ITEM_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
echo "OK"

# 25. Reconsultar Orçamento com Resumo e Livre para Investir
echo -n "25. Validando cálculo de realizado vs. orçado e Livre para Investir... "
BUDGET_CHECK_RESP=$(curl -s -w "\n%{http_code}" -X GET "${BASE_URL}/v1/budgets" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")
HTTP_CODE=$(echo "${BUDGET_CHECK_RESP}" | tail -n1)
BODY=$(echo "${BUDGET_CHECK_RESP}" | sed '$d')
if [ "${HTTP_CODE}" -ne 200 ]; then
    echo "FALHOU (HTTP ${HTTP_CODE})"
    echo "${BODY}"
    exit 1
fi
FREE_TO_INVEST=$(echo "${BODY}" | grep -o '"free_to_invest_cents":[0-9]*' | cut -d':' -f2)
echo "OK (Livre para Investir: R$ $(echo "scale=2; ${FREE_TO_INVEST}/100" | bc))"

# 26. Sabotagens Adicionais da Fase 1
echo -n "26. Teste de Sabotagem: Transferência para mesma conta (deve ser 400)... "
SAB_TRANS_PAYLOAD=$(cat <<EOF
{
  "account_id": "${ACCOUNT_ID}",
  "destination_account_id": "${ACCOUNT_ID}",
  "kind": "transfer",
  "amount_cents": 5000,
  "description": "Tentativa inválida"
}
EOF
)
SAB3_RESP=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/v1/transactions" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${SAB_TRANS_PAYLOAD}")
HTTP_CODE=$(echo "${SAB3_RESP}" | tail -n1)
if [ "${HTTP_CODE}" -ne 400 ]; then
    echo "FALHOU (Esperava 400, recebeu ${HTTP_CODE})"
    exit 1
fi
echo "OK (400)"

echo "=================================================="
echo "🎉 TODOS OS 26 SMOKE TESTS PASSARAM COM SUCESSO!"
echo "=================================================="

