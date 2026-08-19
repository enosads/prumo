-- name: CreateCreditCard :one
INSERT INTO credit_cards (
    account_id, family_id, name, last_four_digits, credit_limit_cents, closing_day, due_day, color
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8
)
RETURNING *;

-- name: ListCreditCardsByFamilyID :many
SELECT cc.*, a.name as account_name
FROM credit_cards cc
JOIN accounts a ON a.id = cc.account_id
WHERE cc.family_id = $1
ORDER BY cc.name ASC;

-- name: GetCreditCardByID :one
SELECT * FROM credit_cards
WHERE id = $1 AND family_id = $2;

-- name: GetCreditCardByAccountID :one
SELECT * FROM credit_cards
WHERE account_id = $1 AND family_id = $2;

-- name: CreateCreditCardInvoice :one
INSERT INTO credit_card_invoices (
    credit_card_id, family_id, period_year, period_month, closing_date, due_date, total_amount_cents, status
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8
)
ON CONFLICT (credit_card_id, period_year, period_month) DO UPDATE
SET total_amount_cents = EXCLUDED.total_amount_cents,
    updated_at = now()
RETURNING *;

-- name: GetCreditCardInvoiceByID :one
SELECT * FROM credit_card_invoices
WHERE id = $1 AND family_id = $2;

-- name: GetCreditCardInvoiceByPeriod :one
SELECT * FROM credit_card_invoices
WHERE credit_card_id = $1 AND period_year = $2 AND period_month = $3;

-- name: ListCreditCardInvoicesByCardID :many
SELECT * FROM credit_card_invoices
WHERE credit_card_id = $1
ORDER BY period_year DESC, period_month DESC;

-- name: UpdateCreditCardInvoiceTotals :one
UPDATE credit_card_invoices
SET total_amount_cents = $3,
    updated_at = now()
WHERE id = $1 AND family_id = $2
RETURNING *;

-- name: UpdateCreditCardInvoicePaid :one
UPDATE credit_card_invoices
SET paid_amount_cents = paid_amount_cents + $3,
    status = $4,
    updated_at = now()
WHERE id = $1 AND family_id = $2
RETURNING *;

-- name: ListFutureInstallmentsByCardID :many
SELECT t.*, cci.period_year, cci.period_month, cci.due_date, u.full_name as author_name, tu.full_name as target_name
FROM transactions t
JOIN credit_card_invoices cci ON cci.id = t.credit_card_invoice_id
JOIN credit_cards cc ON cc.id = cci.credit_card_id
JOIN users u ON u.id = t.created_by_user_id
LEFT JOIN users tu ON tu.id = t.target_user_id
WHERE cc.id = $1 AND t.family_id = $2 AND (cci.period_year > $3 OR (cci.period_year = $3 AND cci.period_month >= $4))
ORDER BY cci.period_year ASC, cci.period_month ASC, t.transacted_at ASC;

