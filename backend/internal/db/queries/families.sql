-- name: CreateFamily :one
INSERT INTO families (
    name, base_currency
) VALUES (
    $1, $2
)
RETURNING *;

-- name: GetFamilyByID :one
SELECT * FROM families
WHERE id = $1;

-- name: AddFamilyMember :one
INSERT INTO family_members (
    family_id, user_id, role, nickname
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: GetFamilyMemberRole :one
SELECT role FROM family_members
WHERE family_id = $1 AND user_id = $2;

-- name: ListFamiliesByUserID :many
SELECT f.*, fm.role, fm.nickname
FROM families f
JOIN family_members fm ON fm.family_id = f.id
WHERE fm.user_id = $1
ORDER BY f.created_at ASC;

-- name: ListFamilyMembers :many
SELECT fm.*, u.email, u.full_name, u.avatar_url
FROM family_members fm
JOIN users u ON u.id = fm.user_id
WHERE fm.family_id = $1
ORDER BY fm.joined_at ASC;

-- name: UpdateFamilyMemberRole :one
UPDATE family_members
SET role = $3, nickname = $4
WHERE family_id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteFamilyMember :exec
DELETE FROM family_members
WHERE family_id = $1 AND user_id = $2;

-- name: CreateFamilyInvitation :one
INSERT INTO family_invitations (
    family_id, invited_by_user_id, email, role, invite_code, expires_at
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING *;

-- name: GetFamilyInvitationByCode :one
SELECT * FROM family_invitations
WHERE invite_code = $1 AND status = 'pending' AND expires_at > now();

-- name: AcceptFamilyInvitation :one
UPDATE family_invitations
SET status = 'accepted'
WHERE id = $1
RETURNING *;
