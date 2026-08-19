ALTER TABLE categories ADD COLUMN IF NOT EXISTS slug VARCHAR(60);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS system_only BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_categories_family_slug ON categories(family_id, slug);

-- Preenchimento retroativo para categorias existentes
UPDATE categories SET slug = 'food' WHERE slug IS NULL AND (name ILIKE '%alimenta%' OR name ILIKE '%mercado%');
UPDATE categories SET slug = 'housing' WHERE slug IS NULL AND (name ILIKE '%moradia%' OR name ILIKE '%aluguel%');
UPDATE categories SET slug = 'bills' WHERE slug IS NULL AND (name ILIKE '%contas%' OR name ILIKE '%assinatura%');
UPDATE categories SET slug = 'transport' WHERE slug IS NULL AND name ILIKE '%transporte%';
UPDATE categories SET slug = 'health' WHERE slug IS NULL AND (name ILIKE '%saúde%' OR name ILIKE '%saude%' OR name ILIKE '%farmácia%');
UPDATE categories SET slug = 'education' WHERE slug IS NULL AND (name ILIKE '%educação%' OR name ILIKE '%educacao%');
UPDATE categories SET slug = 'leisure' WHERE slug IS NULL AND (name ILIKE '%lazer%' OR name ILIKE '%viage%');
UPDATE categories SET slug = 'personal_care' WHERE slug IS NULL AND name ILIKE '%cuidado%';
UPDATE categories SET slug = 'shopping' WHERE slug IS NULL AND (name ILIKE '%compra%' OR name ILIKE '%roupa%');
UPDATE categories SET slug = 'giving' WHERE slug IS NULL AND (name ILIKE '%doação%' OR name ILIKE '%presente%');
UPDATE categories SET slug = 'financial' WHERE slug IS NULL AND (name ILIKE '%taxa%' OR name ILIKE '%imposto%');
UPDATE categories SET slug = 'income' WHERE slug IS NULL AND (name ILIKE '%salário%' OR name ILIKE '%salario%' OR name ILIKE '%receita%' OR name ILIKE '%rendimento%');
UPDATE categories SET slug = 'transfer' WHERE slug IS NULL AND name ILIKE '%transferência%';
UPDATE categories SET slug = 'uncategorized', system_only = TRUE WHERE slug IS NULL AND (name ILIKE '%não categorizado%' OR name ILIKE '%uncategorized%');
