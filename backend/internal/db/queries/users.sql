-- name: CreateUser :one
INSERT INTO users (
    email, full_name, password_hash, avatar_url
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users
WHERE id = $1 AND is_active = TRUE;

-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = $1 AND is_active = TRUE;

-- name: CreateAuthIdentity :one
INSERT INTO auth_identities (
    user_id, provider, provider_user_id, email
) VALUES (
    $1, $2, $3, $4
)
RETURNING *;

-- name: GetAuthIdentity :one
SELECT * FROM auth_identities
WHERE provider = $1 AND provider_user_id = $2;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (
    user_id, token_hash, expires_at
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: GetRefreshToken :one
SELECT * FROM refresh_tokens
WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > now();

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens
SET revoked_at = now()
WHERE token_hash = $1;

-- name: RegisterUserDevice :one
INSERT INTO user_devices (
    user_id, platform, apns_token, fcm_token, app_version, device_model
) VALUES (
    $1, $2, $3, $4, $5, $6
)
ON CONFLICT (user_id, apns_token) DO UPDATE
SET platform = EXCLUDED.platform,
    fcm_token = EXCLUDED.fcm_token,
    app_version = EXCLUDED.app_version,
    device_model = EXCLUDED.device_model,
    last_seen_at = now()
RETURNING *;
