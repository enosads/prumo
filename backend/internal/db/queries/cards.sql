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

-- name: GetCreditCardInvoiceByPeriod :one
SELECT * FROM credit_card_invoices
WHERE credit_card_id = $1 AND period_year = $2 AND period_month = $3;

-- name: ListCreditCardInvoicesByCardID :many
SELECT * FROM credit_card_invoices
WHERE credit_card_id = $1
ORDER BY period_year DESC, period_month DESC;
