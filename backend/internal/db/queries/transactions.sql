-- name: CreateTransaction :one
INSERT INTO transactions (
    family_id, account_id, category_id, created_by_user_id, target_user_id,
    kind, amount_cents, description, transacted_at, status,
    credit_card_invoice_id, installment_number, installment_total, installment_group_id,
    tags, notes
) VALUES (
    $1, $2, $3, $4, $5,
    $6, $7, $8, $9, $10,
    $11, $12, $13, $14,
    $15, $16
)
RETURNING *;

-- name: GetTransactionByID :one
SELECT t.*, c.name as category_name, a.name as account_name, u.full_name as author_name
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
JOIN accounts a ON a.id = t.account_id
JOIN users u ON u.id = t.created_by_user_id
WHERE t.id = $1 AND t.family_id = $2;

-- name: ListTransactionsByFamilyID :many
SELECT t.*, c.name as category_name, c.icon as category_icon, c.color as category_color, a.name as account_name
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
JOIN accounts a ON a.id = t.account_id
WHERE t.family_id = $1
  AND ($2::uuid IS NULL OR t.account_id = $2)
  AND ($3::uuid IS NULL OR t.category_id = $3)
  AND ($4::timestamptz IS NULL OR t.transacted_at >= $4)
  AND ($5::timestamptz IS NULL OR t.transacted_at <= $5)
ORDER BY t.transacted_at DESC, t.created_at DESC
LIMIT $6 OFFSET $7;

-- name: ListTransactionsByFamilyIDWithFilters :many
SELECT t.*, c.name as category_name, c.icon as category_icon, c.color as category_color, a.name as account_name, u.full_name as author_name, tu.full_name as target_name
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
JOIN accounts a ON a.id = t.account_id
JOIN users u ON u.id = t.created_by_user_id
LEFT JOIN users tu ON tu.id = t.target_user_id
WHERE t.family_id = sqlc.arg('family_id')
  AND (sqlc.narg('account_id')::uuid IS NULL OR t.account_id = sqlc.narg('account_id'))
  AND (sqlc.narg('category_id')::uuid IS NULL OR t.category_id = sqlc.narg('category_id'))
  AND (sqlc.narg('kind')::varchar IS NULL OR t.kind = sqlc.narg('kind'))
  AND (sqlc.narg('user_id')::uuid IS NULL OR t.target_user_id = sqlc.narg('user_id') OR t.created_by_user_id = sqlc.narg('user_id'))
  AND (sqlc.narg('from_date')::timestamptz IS NULL OR t.transacted_at >= sqlc.narg('from_date'))
  AND (sqlc.narg('to_date')::timestamptz IS NULL OR t.transacted_at <= sqlc.narg('to_date'))
ORDER BY t.transacted_at DESC, t.created_at DESC
LIMIT sqlc.arg('limit_count') OFFSET sqlc.arg('offset_count');

-- name: ListTransactionsByInvoiceID :many
SELECT t.*, c.name as category_name, c.icon as category_icon, c.color as category_color, u.full_name as author_name, tu.full_name as target_name
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
JOIN users u ON u.id = t.created_by_user_id
LEFT JOIN users tu ON tu.id = t.target_user_id
WHERE t.credit_card_invoice_id = $1 AND t.family_id = $2
ORDER BY t.transacted_at DESC, t.created_at DESC;

-- name: ListTransactionsByInstallmentGroupID :many
SELECT t.*, cci.period_year, cci.period_month
FROM transactions t
LEFT JOIN credit_card_invoices cci ON cci.id = t.credit_card_invoice_id
WHERE t.installment_group_id = $1 AND t.family_id = $2
ORDER BY t.installment_number ASC;

-- name: UpdateTransactionInvoiceAndAmount :one
UPDATE transactions
SET credit_card_invoice_id = $3,
    amount_cents = $4,
    notes = $5,
    updated_at = now()
WHERE id = $1 AND family_id = $2
RETURNING *;

-- name: GetCategorySpendingForPeriod :many
SELECT category_id, COALESCE(SUM(amount_cents), 0)::bigint as total_spent_cents
FROM transactions
WHERE family_id = sqlc.arg('family_id')
  AND kind = 'expense'
  AND status = 'completed'
  AND transacted_at >= sqlc.arg('start_date')
  AND transacted_at <= sqlc.arg('end_date')
GROUP BY category_id;

-- name: GetMonthlyCashFlowTotals :one
SELECT 
    COALESCE(SUM(CASE WHEN kind = 'income' THEN amount_cents ELSE 0 END), 0)::bigint as total_income_cents,
    COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount_cents ELSE 0 END), 0)::bigint as total_expense_cents
FROM transactions
WHERE family_id = sqlc.arg('family_id')
  AND status = 'completed'
  AND transacted_at >= sqlc.arg('start_date')
  AND transacted_at <= sqlc.arg('end_date');

-- name: DeleteTransaction :exec
DELETE FROM transactions
WHERE id = $1 AND family_id = $2;

