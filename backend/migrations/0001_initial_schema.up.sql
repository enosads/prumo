CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ============================================================================
-- 1. USUÁRIOS E AUTENTICAÇÃO
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email CITEXT NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255),
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE auth_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(30) NOT NULL, -- 'apple', 'google', 'email'
    provider_user_id VARCHAR(255) NOT NULL,
    email CITEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform VARCHAR(20) NOT NULL, -- 'ios', 'android', 'web'
    apns_token VARCHAR(255),
    fcm_token VARCHAR(255),
    app_version VARCHAR(30),
    device_model VARCHAR(100),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, apns_token)
);

-- ============================================================================
-- 2. NÚCLEO FAMILIAR E MULTI-TENANCY
-- ============================================================================

CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    base_currency VARCHAR(3) NOT NULL DEFAULT 'BRL',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    nickname VARCHAR(60),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (family_id, user_id)
);

CREATE TABLE family_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    invited_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email CITEXT NOT NULL,
    role VARCHAR(30) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member', 'viewer')),
    invite_code VARCHAR(64) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. CONTAS FINANCEIRAS E CARTÕES DE CRÉDITO
-- ============================================================================

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    kind VARCHAR(30) NOT NULL CHECK (kind IN ('checking', 'savings', 'investment', 'cash', 'credit_card')),
    visibility VARCHAR(20) NOT NULL DEFAULT 'shared' CHECK (visibility IN ('shared', 'private')),
    currency VARCHAR(3) NOT NULL DEFAULT 'BRL',
    initial_balance_cents BIGINT NOT NULL DEFAULT 0,
    current_balance_cents BIGINT NOT NULL DEFAULT 0,
    color VARCHAR(7),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE credit_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    last_four_digits VARCHAR(4),
    credit_limit_cents BIGINT NOT NULL,
    closing_day SMALLINT NOT NULL CHECK (closing_day BETWEEN 1 AND 31),
    due_day SMALLINT NOT NULL CHECK (due_day BETWEEN 1 AND 31),
    color VARCHAR(7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE credit_card_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_card_id UUID NOT NULL REFERENCES credit_cards(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    period_year SMALLINT NOT NULL,
    period_month SMALLINT NOT NULL,
    closing_date DATE NOT NULL,
    due_date DATE NOT NULL,
    total_amount_cents BIGINT NOT NULL DEFAULT 0,
    paid_amount_cents BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'paid', 'partially_paid', 'overdue')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (credit_card_id, period_year, period_month)
);

-- ============================================================================
-- 4. CATEGORIAS, TRANSAÇÕES E PARCELAMENTOS
-- ============================================================================

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    icon VARCHAR(60),
    color VARCHAR(7),
    kind VARCHAR(20) NOT NULL DEFAULT 'both' CHECK (kind IN ('income', 'expense', 'both')),
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('income', 'expense', 'transfer')),
    amount_cents BIGINT NOT NULL,
    description VARCHAR(255) NOT NULL,
    transacted_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled')),
    credit_card_invoice_id UUID REFERENCES credit_card_invoices(id) ON DELETE SET NULL,
    installment_number SMALLINT DEFAULT 1,
    installment_total SMALLINT DEFAULT 1,
    installment_group_id UUID,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 5. ORÇAMENTOS POR ENVELOPE
-- ============================================================================

CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    period_year SMALLINT NOT NULL,
    period_month SMALLINT NOT NULL,
    total_allocated_cents BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (family_id, period_year, period_month)
);

CREATE TABLE budget_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    allocated_amount_cents BIGINT NOT NULL DEFAULT 0,
    rollover_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (budget_id, category_id)
);

-- ============================================================================
-- 6. INVESTIMENTOS (B3, GLOBAL, RENDA FIXA, FUNDOS) E TESE
-- ============================================================================

CREATE TABLE investment_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticker VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    asset_class VARCHAR(30) NOT NULL CHECK (asset_class IN ('brazilian_stock', 'fii', 'brazilian_etf', 'bdr', 'fixed_income', 'us_stock', 'us_etf', 'reit', 'crypto', 'funds')),
    currency VARCHAR(3) NOT NULL DEFAULT 'BRL',
    sector VARCHAR(80),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE asset_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES investment_assets(id) ON DELETE CASCADE,
    price_cents BIGINT NOT NULL,
    change_pct NUMERIC(6, 3),
    as_of TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (asset_id, as_of)
);

CREATE TABLE investment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    asset_id UUID NOT NULL REFERENCES investment_assets(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    order_type VARCHAR(10) NOT NULL CHECK (order_type IN ('buy', 'sell')),
    quantity NUMERIC(18, 8) NOT NULL,
    unit_price_cents BIGINT NOT NULL,
    fees_cents BIGINT NOT NULL DEFAULT 0,
    total_amount_cents BIGINT NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE investment_positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    asset_id UUID NOT NULL REFERENCES investment_assets(id) ON DELETE RESTRICT,
    quantity NUMERIC(18, 8) NOT NULL DEFAULT 0,
    average_price_cents BIGINT NOT NULL DEFAULT 0,
    total_cost_cents BIGINT NOT NULL DEFAULT 0,
    accumulated_dividends_cents BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (account_id, asset_id)
);

CREATE TABLE investment_theses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    risk_profile VARCHAR(30) NOT NULL CHECK (risk_profile IN ('conservative', 'moderate', 'bold', 'aggressive')),
    target_allocations JSONB NOT NULL DEFAULT '{}'::jsonb,
    rebalancing_tolerance_pct NUMERIC(5, 2) NOT NULL DEFAULT 5.00,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (family_id)
);

-- ============================================================================
-- 7. AGENTE DE IA & AUDITORIA DE TOOL CALLING
-- ============================================================================

CREATE TABLE ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL DEFAULT 'Nova conversa',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content TEXT,
    tool_calls JSONB,
    tool_call_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_tool_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tool_name VARCHAR(80) NOT NULL,
    parameters JSONB NOT NULL,
    result JSONB,
    status VARCHAR(20) NOT NULL DEFAULT 'pending_approval' CHECK (status IN ('pending_approval', 'approved', 'rejected', 'executed', 'failed')),
    approval_token VARCHAR(120),
    executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- ÍNDICES DE PERFORMANCE E MULTI-TENANCY
-- ============================================================================

CREATE INDEX idx_family_members_family ON family_members(family_id);
CREATE INDEX idx_family_members_user ON family_members(user_id);
CREATE INDEX idx_accounts_family ON accounts(family_id);
CREATE INDEX idx_accounts_owner ON accounts(owner_user_id);
CREATE INDEX idx_transactions_family_date ON transactions(family_id, transacted_at DESC);
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_category ON transactions(category_id);
CREATE INDEX idx_transactions_invoice ON transactions(credit_card_invoice_id);
CREATE INDEX idx_transactions_installment_group ON transactions(installment_group_id) WHERE installment_group_id IS NOT NULL;
CREATE INDEX idx_invoices_card ON credit_card_invoices(credit_card_id);
CREATE INDEX idx_investment_orders_family ON investment_orders(family_id);
CREATE INDEX idx_investment_positions_family ON investment_positions(family_id);
CREATE INDEX idx_ai_messages_conv ON ai_messages(conversation_id, created_at ASC);
CREATE INDEX idx_ai_tool_executions_family ON ai_tool_executions(family_id);
