-- name: CreateAccount :one
INSERT INTO accounts (
    family_id, owner_user_id, name, kind, visibility, currency, initial_balance_cents, current_balance_cents, color
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9
)
RETURNING *;

-- name: GetAccountByID :one
SELECT * FROM accounts
WHERE id = $1 AND family_id = $2;

-- name: ListAccountsByFamilyID :many
SELECT a.*, u.full_name as owner_name
FROM accounts a
JOIN users u ON u.id = a.owner_user_id
WHERE a.family_id = $1 AND a.is_archived = FALSE
ORDER BY a.name ASC;

-- name: UpdateAccountBalance :one
UPDATE accounts
SET current_balance_cents = current_balance_cents + $3,
    updated_at = now()
WHERE id = $1 AND family_id = $2
RETURNING *;

-- name: ArchiveAccount :exec
UPDATE accounts
SET is_archived = TRUE, updated_at = now()
WHERE id = $1 AND family_id = $2;
