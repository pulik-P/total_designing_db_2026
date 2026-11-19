-- Создаем пользователя, если его нет
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END
$$;

-- Выдаем полные права на схему: USAGE + CREATE (FOOD-109: ALL PRIVILEGES на схему)
GRANT ALL PRIVILEGES ON SCHEMA vervykishko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA vervykishko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA vervykishko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA vervykishko_food TO inspector;

-- Даем права на будущие таблицы (если вдруг будут создаваться)
ALTER DEFAULT PRIVILEGES IN SCHEMA vervykishko_food GRANT ALL ON TABLES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA vervykishko_food GRANT ALL ON SEQUENCES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA vervykishko_food GRANT ALL ON FUNCTIONS TO inspector;

-- Даем права на схему exts (для генерации UUID)
GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

-- Даем права на information_schema и pg_catalog (обычно они есть по умолчанию, но явно проверим)
GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog TO inspector;