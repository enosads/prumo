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

-- name: DeleteTransaction :exec
DELETE FROM transactions
WHERE id = $1 AND family_id = $2;
