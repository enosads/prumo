-- name: UpsertAsset :one
INSERT INTO investment_assets (
    ticker, name, asset_class, currency, sector
) VALUES (
    $1, $2, $3, $4, $5
)
ON CONFLICT (ticker) DO UPDATE
SET name = EXCLUDED.name,
    sector = EXCLUDED.sector,
    updated_at = now()
RETURNING *;

-- name: GetAssetByTicker :one
SELECT * FROM investment_assets
WHERE ticker = $1;

-- name: ListAssets :many
SELECT * FROM investment_assets
WHERE is_active = TRUE
ORDER BY ticker ASC;

-- name: CreateInvestmentOrder :one
INSERT INTO investment_orders (
    family_id, account_id, asset_id, user_id, order_type, quantity, unit_price_cents, fees_cents, total_amount_cents, executed_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
)
RETURNING *;

-- name: UpsertInvestmentPosition :one
INSERT INTO investment_positions (
    family_id, account_id, asset_id, quantity, average_price_cents, total_cost_cents, accumulated_dividends_cents
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
)
ON CONFLICT (account_id, asset_id) DO UPDATE
SET quantity = EXCLUDED.quantity,
    average_price_cents = EXCLUDED.average_price_cents,
    total_cost_cents = EXCLUDED.total_cost_cents,
    accumulated_dividends_cents = EXCLUDED.accumulated_dividends_cents,
    updated_at = now()
RETURNING *;

-- name: ListInvestmentPositionsByFamilyID :many
SELECT ip.*, ia.ticker, ia.name as asset_name, ia.asset_class, ia.currency as asset_currency, a.name as account_name
FROM investment_positions ip
JOIN investment_assets ia ON ia.id = ip.asset_id
JOIN accounts a ON a.id = ip.account_id
WHERE ip.family_id = $1 AND ip.quantity > 0
ORDER BY ia.ticker ASC;

-- name: UpsertInvestmentThesis :one
INSERT INTO investment_theses (
    family_id, risk_profile, target_allocations, rebalancing_tolerance_pct, notes
) VALUES (
    $1, $2, $3, $4, $5
)
ON CONFLICT (family_id) DO UPDATE
SET risk_profile = EXCLUDED.risk_profile,
    target_allocations = EXCLUDED.target_allocations,
    rebalancing_tolerance_pct = EXCLUDED.rebalancing_tolerance_pct,
    notes = EXCLUDED.notes,
    updated_at = now()
RETURNING *;

-- name: GetInvestmentThesisByFamilyID :one
SELECT * FROM investment_theses
WHERE family_id = $1;
