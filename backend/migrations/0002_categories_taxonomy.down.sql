DROP INDEX IF EXISTS idx_categories_family_slug;
ALTER TABLE categories DROP COLUMN IF EXISTS system_only;
ALTER TABLE categories DROP COLUMN IF EXISTS slug;
