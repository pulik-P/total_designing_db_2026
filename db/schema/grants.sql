-- FOOD-109. Роль inspector — аудитор, под которой преподаватель проверяет работу.
--
-- Принцип минимальных привилегий: роль получает ровно те права, которые нужны
-- для проверки (чтение и изменение данных, вызов процедур), и НЕ получает
-- автоматических прав на будущие объекты. Поэтому здесь нет
-- ALTER DEFAULT PRIVILEGES: иначе любая новая таблица автоматически
-- открывалась бы этой учётке, что и приводит к утечкам.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END
$$;

-- Схема: USAGE для работы с объектами, CREATE — по требованию FOOD-109
GRANT USAGE, CREATE ON SCHEMA vervykishko_food TO inspector;

-- Данные: проверка включает генерацию, очистку и добавление блюда,
-- поэтому аудитору нужны SELECT/INSERT/UPDATE/DELETE на таблицы схемы.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA vervykishko_food TO inspector;

-- Вызов функций и процедур (insert_test_data, erase_test_data, add_product,
-- courier_salary, get_statistic, rating_change)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA vervykishko_food TO inspector;

-- UUID генерируются через exts.uuid_generate_v4()
GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;

-- Каталоги для проверки структуры (по умолчанию доступны, фиксируем явно)
GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog TO inspector;

-- В рабочей системе роли были бы разными:
--   app_role   — DML только на order/order_structure/payment/review;
--   analyst    — SELECT только на how_much_money и get_statistic();
--   inspector  — эта тестовая роль с ограниченным сроком действия.
-- Выдавать всем ролям ALL на все таблицы нельзя: клиентские данные
-- (client.password, client.phone_number) не должны быть доступны аналитику.
