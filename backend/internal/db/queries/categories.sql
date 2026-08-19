-- name: CreateCategory :one
INSERT INTO categories (
    family_id, name, icon, color, kind, parent_id, slug, system_only
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8
)
RETURNING *;

-- name: ListCategoriesByFamilyID :many
SELECT * FROM categories
WHERE family_id = $1
ORDER BY name ASC;

-- name: ListVisibleCategoriesByFamilyID :many
SELECT * FROM categories
WHERE family_id = $1 AND system_only = FALSE
ORDER BY name ASC;

-- name: GetCategoryByID :one
SELECT * FROM categories
WHERE id = $1 AND family_id = $2;

-- name: GetCategoryBySlug :one
SELECT * FROM categories
WHERE family_id = $1 AND slug = $2;

-- name: UpdateCategory :one
UPDATE categories
SET name = $3,
    icon = $4,
    color = $5,
    kind = $6,
    parent_id = $7,
    slug = $8,
    system_only = $9
WHERE id = $1 AND family_id = $2
RETURNING *;

-- name: CountCategoriesByFamilyID :one
SELECT count(*) FROM categories
WHERE family_id = $1;

-- name: DeleteCategory :exec
DELETE FROM categories
WHERE id = $1 AND family_id = $2;
