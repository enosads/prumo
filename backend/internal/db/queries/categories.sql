-- name: CreateCategory :one
INSERT INTO categories (
    family_id, name, icon, color, kind, parent_id
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING *;

-- name: ListCategoriesByFamilyID :many
SELECT * FROM categories
WHERE family_id = $1
ORDER BY name ASC;

-- name: GetCategoryByID :one
SELECT * FROM categories
WHERE id = $1 AND family_id = $2;

-- name: DeleteCategory :exec
DELETE FROM categories
WHERE id = $1 AND family_id = $2;
