-- name: GetBudgetByPeriod :one
SELECT * FROM budgets
WHERE family_id = $1 AND period_year = $2 AND period_month = $3;

-- name: GetBudgetByID :one
SELECT * FROM budgets
WHERE id = $1 AND family_id = $2;

-- name: CreateBudget :one
INSERT INTO budgets (
    family_id, period_year, period_month, total_allocated_cents
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: ListBudgetItems :many
SELECT bi.*, c.name as category_name, c.icon as category_icon, c.color as category_color, c.kind as category_kind
FROM budget_items bi
JOIN categories c ON c.id = bi.category_id
WHERE bi.budget_id = $1
ORDER BY c.name ASC;

-- name: UpsertBudgetItem :one
INSERT INTO budget_items (
    budget_id, category_id, allocated_amount_cents, rollover_enabled
) VALUES (
    $1, $2, $3, $4
)
ON CONFLICT (budget_id, category_id) DO UPDATE
SET allocated_amount_cents = EXCLUDED.allocated_amount_cents,
    rollover_enabled = EXCLUDED.rollover_enabled
RETURNING *;

-- name: DeleteBudgetItem :exec
DELETE FROM budget_items
WHERE budget_id = $1 AND category_id = $2;

-- name: UpdateBudgetTotalAllocated :one
UPDATE budgets
SET total_allocated_cents = (
    SELECT COALESCE(SUM(allocated_amount_cents), 0)
    FROM budget_items
    WHERE budget_id = $1
),
updated_at = now()
WHERE id = $1 AND family_id = $2
RETURNING *;
