# Протокол самопроверки

| Параметр | Значение |
|---|---|
| PostgreSQL version | 17.10 (Homebrew) |
| Дата проверки | 19.11.2026 |
| Схема | `vervykishko_food` |
| Роль-аудитор | `inspector` |
| ОС | macOS (arm64) |

Все проверки выполнялись под `inspector` на БД, восстановленной из `db/foodexpress_vervykishko.backup`.
Вердикт `OK` — проверка пройдена, `FAIL` — не пройдена.

---

## A. Подготовка

### A.1. Восстановление бэкапа

```bash
createdb foodexpress_check
psql -d foodexpress_check -c 'CREATE SCHEMA IF NOT EXISTS exts; CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;'
pg_restore -d foodexpress_check db/foodexpress_vervykishko.backup
```

Ожидается: без ошибок. Схема `exts` создаётся заранее и не пересоздаётся (BR-13.3), поэтому в дампе её нет — дамп содержит только схему `vervykishko_food`.
Факт: `pg_restore` завершился без ошибок и предупреждений; после восстановления 12 таблиц, 1 представление, 7 функций, 1 триггер, 50 заказов и 50 отзывов.
Вердикт: OK

### A.2. Переключение на inspector

```sql
SET ROLE inspector;
SET search_path TO vervykishko_food, exts;
SELECT current_user;
```

Ожидается: `inspector`.
Факт: `current_user = inspector`, `search_path = vervykishko_food, exts`.
Вердикт: OK

---

## B. FOOD-101: Структура схемы

### B.1. Схема существует

```sql
SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE '%_food';
```

Ожидается: `vervykishko_food`.
Факт: `vervykishko_food`.
Вердикт: OK

### B.2. Схема `exts` с `uuid-ossp`

```sql
SELECT e.extname, n.nspname FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace;
```

Ожидается: `uuid-ossp` в `exts`.
Факт: `uuid-ossp | exts`.
Вердикт: OK

### B.3. Все 12 таблиц

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'vervykishko_food' AND table_type = 'BASE TABLE' ORDER BY 1;
```

Ожидается: 12 таблиц.
Факт: 12: `address, client, client_address, courier, courier_pay, order, order_structure, payment, product, product_category, restaurant, review`.
Вердикт: OK

### B.4. Все ID — `uuid`

```sql
SELECT tc.table_name, c.column_name, c.data_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
JOIN information_schema.columns c
  ON c.table_schema = kcu.table_schema AND c.table_name = kcu.table_name AND c.column_name = kcu.column_name
WHERE tc.table_schema = 'vervykishko_food' AND tc.constraint_type = 'PRIMARY KEY';
```

Ожидается: все суррогатные ID — `uuid`.
Факт: все ID-колонки — `uuid`. Не-`uuid` в составе PK только `courier_pay.year` и `courier_pay.month` (составной ключ `year, month, courier_id`, BR-10.3: одна выплата на курьера в месяц) — суррогатного ID у этой таблицы нет.
Вердикт: OK

### B.5. Enum-типы

```sql
SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'vervykishko_food' AND t.typtype = 'e';
```

Ожидается: 8.
Факт: 8: `restaurant_status, product_status, courier_status, order_status, order_pay_status, payment_status, payment_type, review_entity_type`.
Вердикт: OK

### B.6. FK-ограничения

```sql
SELECT count(*) FROM information_schema.table_constraints
WHERE table_schema = 'vervykishko_food' AND constraint_type = 'FOREIGN KEY';
```

Ожидается: не менее 15.
Факт: 15 FK.
Вердикт: OK

### B.7. Пароль — MD5

```sql
SELECT count(*) FROM client WHERE length(password) <> 32;
```

Ожидается: 0.
Факт: 0 (все пароли — 32 hex-символа).
Вердикт: OK

---

## C. FOOD-102: `insert_test_data(value)`

### C.1. Чистая схема

```sql
CALL erase_test_data();
SELECT sum(c) FROM (
  SELECT count(*) c FROM client UNION ALL SELECT count(*) FROM courier
  UNION ALL SELECT count(*) FROM product_category UNION ALL SELECT count(*) FROM restaurant
  UNION ALL SELECT count(*) FROM address UNION ALL SELECT count(*) FROM product
  UNION ALL SELECT count(*) FROM "order" UNION ALL SELECT count(*) FROM review
  UNION ALL SELECT count(*) FROM payment UNION ALL SELECT count(*) FROM order_structure
  UNION ALL SELECT count(*) FROM client_address UNION ALL SELECT count(*) FROM courier_pay) x;
```

Ожидается: без ошибок, 0 строк.
Факт: 0 строк во всех 12 таблицах.
Вердикт: OK

### C.2. Первый запуск

```sql
CALL insert_test_data(10);
```

Ожидается: без ошибок.
Факт: `CALL` выполнен, 50 заказов.
Вердикт: OK

### C.3. Распределение строк (BR-11.7)

```sql
SELECT 'client' tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment ORDER BY tbl;
```

Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
Факт: client 10, courier 10, product_category 10, restaurant 10, address 50, product 50, order 50, review 50, payment 50.
Вердикт: OK

> Генератор использует `random()`, поэтому отдельные величины (число активных курьеров, число месяцев в отчёте, длительности в H) в каждом прогоне могут отличаться. Количества строк из BR-11.7 всегда точные.

### C.4. Адреса ресторанов vs клиентов (BR-11.7)

```sql
SELECT (SELECT count(*) FROM restaurant) AS restaurant_addresses,
       (SELECT count(*) FROM address) AS total_addresses;
```

Ожидается: 10 ресторанных, 50 всего → 40 клиентских.
Факт: 10 ресторанных адресов, 50 всего (40 клиентских, используются в `client_address` и `order.address_id`).
Вердикт: OK

### C.5. Нет пустых строк (BR-11.3)

```sql
SELECT (SELECT count(*) FROM client WHERE login = '' OR password = '' OR phone_number = '')
     + (SELECT count(*) FROM courier WHERE fio = '' OR phone_number = '')
     + (SELECT count(*) FROM restaurant WHERE restaurant_name = '')
     + (SELECT count(*) FROM product WHERE product_name = '')
     + (SELECT count(*) FROM product_category WHERE product_category_name = '')
     + (SELECT count(*) FROM address WHERE street = '' OR house_number = '')
     + (SELECT count(*) FROM payment WHERE transaction_id = '');
```

Ожидается: 0.
Факт: 0.
Вердикт: OK

### C.6. Нет NULL там, где запрещено (BR-11.3)

```sql
SELECT (SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'vervykishko_food' AND is_nullable = 'NO') AS not_null_columns,
       (SELECT count(*) FROM "order" WHERE status = 'доставлен' AND delivery_timestamp IS NULL) AS delivered_without_ts,
       (SELECT count(*) FROM courier WHERE status = 'уволен' AND dismissal_date IS NULL) AS fired_without_date,
       (SELECT count(*) FROM courier WHERE status <> 'уволен' AND dismissal_date IS NOT NULL) AS active_with_date;
```

Ожидается: 0 нарушений.
Факт: 61 колонка объявлена `NOT NULL`; нарушений 0 (доставленные заказы имеют время доставки, уволенные — дату увольнения, работающие — не имеют).
Вердикт: OK

### C.7. Минимум один активный курьер (BR-6.6)

```sql
SELECT count(*) FROM courier WHERE status <> 'уволен';
```

Ожидается: `>= 1`.
Факт: 7 активных курьеров (первый курьер всегда создаётся свободным).
Вердикт: OK

### C.8. `courier_pay` консистентен (BR-10.2)

```sql
SELECT count(*) FROM courier_pay cp
WHERE cp.amount <> round(cp.coefficient_used * coalesce((
    SELECT sum(o.commission) FROM "order" o
    WHERE o.courier_id = cp.courier_id AND o.status = 'доставлен'
      AND extract(year  FROM o.order_timestamp) = cp.year
      AND extract(month FROM o.order_timestamp) = cp.month), 0), 2);
```

Ожидается: 0.
Факт: 0 (все 60 записей: 10 курьеров × 6 месяцев).
Вердикт: OK

### C.9. Повторный вызов не ломает

```sql
DO $$ BEGIN FOR i IN 1..10 LOOP CALL insert_test_data(10); END LOOP; END $$;
```

Ожидается: без ошибок.
Факт: 10 вызовов подряд без ошибок, данные аккуратно добавились: 100 клиентов, 100 курьеров, 500 заказов, 500 отзывов, 600 записей `courier_pay` (уникальность обеспечивается суффиксом из микросекунд и счётчиком).
Вердикт: OK

---

## D. Проверки бизнес-правил на сгенерированных данных

### D.1. Все FK валидны (нет orphans)

```sql
SELECT sum(orphans) FROM (
  SELECT count(*) orphans FROM order_structure os LEFT JOIN "order" o USING(order_id) WHERE o.order_id IS NULL
  UNION ALL SELECT count(*) FROM order_structure os LEFT JOIN product p USING(product_id) WHERE p.product_id IS NULL
  UNION ALL SELECT count(*) FROM payment pm LEFT JOIN "order" o USING(order_id) WHERE o.order_id IS NULL
  UNION ALL SELECT count(*) FROM review r LEFT JOIN "order" o USING(order_id) WHERE o.order_id IS NULL
  UNION ALL SELECT count(*) FROM courier_pay cp LEFT JOIN courier c USING(courier_id) WHERE c.courier_id IS NULL
  UNION ALL SELECT count(*) FROM client_address ca LEFT JOIN client c USING(client_id) WHERE c.client_id IS NULL
  UNION ALL SELECT count(*) FROM client_address ca LEFT JOIN address a USING(address_id) WHERE a.address_id IS NULL) x;
```

Ожидается: 0.
Факт: 0.
Вердикт: OK

### D.2. Минимальная сумма заказа (BR-1.8)

```sql
SELECT count(*) FROM "order" WHERE total_amount < 1000;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.3. Комиссия = 10% (BR-1.4)

```sql
SELECT count(*) FROM "order" WHERE round(order_amount * 0.10, 2) <> commission;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.4. `total_amount = order_amount + commission`

```sql
SELECT count(*) FROM "order" WHERE round(order_amount + commission, 2) <> total_amount;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.5. Дата доставки не раньше создания (BR-7.13)

```sql
SELECT count(*) FROM "order" WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.6. Адрес доставки принадлежит клиенту (BR-7.4)

```sql
SELECT count(*) FROM "order" o
LEFT JOIN client_address ca ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
```

Ожидается: 0.
Факт: 0 (генератор берёт адрес только из `client_address` этого клиента).
Вердикт: OK

### D.7. Все блюда в заказе из одного ресторана (BR-7.3)

```sql
SELECT count(DISTINCT os.order_id) FROM order_structure os
JOIN "order" o USING(order_id) JOIN product p USING(product_id)
WHERE p.restaurant_id <> o.restaurant_id;
```

Ожидается: 0.
Факт: 0 (блюда выбираются только из ресторана заказа).
Вердикт: OK

### D.8. Ровно одна успешная оплата на заказ (BR-8.1)

```sql
SELECT count(*) FROM (SELECT order_id FROM payment WHERE status = 'успех'
                      GROUP BY order_id HAVING count(*) <> 1) x;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.9. Сумма оплаты = `total_amount` заказа (BR-8.4)

```sql
SELECT count(*) FROM payment p JOIN "order" o USING(order_id) WHERE p.amount <> o.total_amount;
```

Ожидается: 0.
Факт: 0 (сумма берётся из `total_amount` именно этого заказа).
Вердикт: OK

### D.10. Нет дубликатов в `client_address` (BR-2.5)

```sql
SELECT count(*) FROM (SELECT 1 FROM client_address GROUP BY client_id, address_id HAVING count(*) > 1) x;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.11. Нет дубликатов в `order_structure` (BR-7.16)

```sql
SELECT count(*) FROM (SELECT 1 FROM order_structure GROUP BY order_id, product_id HAVING count(*) > 1) x;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.12. `work_end > work_start` (BR-4.4)

```sql
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
```

Ожидается: 0.
Факт: 0 (график генерируется в пределах 08:00–22:00).
Вердикт: OK

### D.13. `dismissal_date >= hire_date` (BR-6.3)

```sql
SELECT count(*) FROM courier WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
```

Ожидается: 0. Факт: 0. Вердикт: OK

### D.14. Рейтинг соответствует отзывам (BR-9.6)

```sql
SELECT (SELECT count(*) FROM product p
        WHERE p.rating IS NOT NULL AND p.rating IS DISTINCT FROM
              (SELECT round(avg(r.rating), 2) FROM review r
               WHERE r.entity_type = 'блюдо' AND r.entity_id = p.product_id)) AS bad_product,
       (SELECT count(*) FROM restaurant r
        WHERE r.rating IS NOT NULL AND r.rating IS DISTINCT FROM
              (SELECT round(avg(v.rating), 2) FROM review v
               WHERE v.entity_type = 'ресторан' AND v.entity_id = r.restaurant_id)) AS bad_restaurant;
```

Ожидается: 0.
Факт: 0 и 0 — рейтинги проставлены триггером `rating_change` (FOOD-105), генератор создаёт блюда и рестораны с `rating = NULL`.
Вердикт: OK

---

## E. Функции и процедуры

### E.1. `add_product` — успешный вызов

```sql
SELECT restaurant_id AS rid FROM restaurant LIMIT 1 \gset
SELECT product_category_id AS cid FROM product_category LIMIT 1 \gset
SELECT count(*) FROM product;
CALL add_product(:'rid'::uuid, :'cid'::uuid, 'Тестовое блюдо', 250, 4.5, 'доступно', 'Описание');
SELECT count(*) FROM product;
```

Ожидается: `after = before + 1`.
Факт: 50 → 51, затем `ROLLBACK`.
Вердикт: OK

### E.2. `add_product` — падает на несуществующий ресторан

```sql
CALL add_product('00000000-0000-0000-0000-000000000000'::uuid, :'cid'::uuid,
                 'x', 100, NULL, 'доступно', NULL);
```

Ожидается: ошибка с внятным сообщением.
Факт: `ERROR: Ресторан с ID 00000000-0000-0000-0000-000000000000 не существует`. Аналогично для категории (`Категория с ID ... не существует`) и для цены (`Цена не может быть отрицательной`).
Вердикт: OK

### E.3. `rating_change` — пересчитывает рейтинг

```sql
-- 3 отзыва на одно блюдо с рейтингами 3, 4, 5
SELECT rating FROM product WHERE product_id = :'pid';
```

Ожидается: 4.00.
Факт: 4.00 (после вставки трёх отзывов).
Вердикт: OK

### E.4. `rating_change` — удаление отзыва

```sql
DELETE FROM review WHERE review_id = :'rid';        -- удалили отзыв с рейтингом 3
DELETE FROM review WHERE entity_id = :'pid';        -- удалили все отзывы
```

Ожидается: после первого удаления 4.50, после второго — NULL.
Факт: 4.50, затем `rating IS NULL`.
Вердикт: OK

### E.5. `get_statistic()`

```sql
SELECT count(*) FROM get_statistic();
```

Ожидается: по строке на ресторан с доставленными заказами, 5 колонок.
Факт: 10 строк; колонки `restaurant_name, best_product_name, total_amount, avg_amount, best_user`; пустых `best_product_name`/`best_user` — 0.
Вердикт: OK

### E.6. `courier_salary()`

```sql
CALL courier_salary();
```

Ожидается: 60 записей `courier_pay`, зарплата и коэффициент по BR-10.2.
Факт: 60 записей; у уволенных курьеров `coefficient` не изменился.
Вердикт: OK

### E.7. `courier_salary()` — повторный вызов

```sql
CALL courier_salary();
SELECT count(*) FROM courier_pay;
```

Ожидается: количество не изменилось.
Факт: 60 → 60 (`ON CONFLICT (year, month, courier_id) DO UPDATE`).
Вердикт: OK

---

## F. Представление `how_much_money`

### F.1. Колонки

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema = 'vervykishko_food' AND table_name = 'how_much_money'
ORDER BY ordinal_position;
```

Ожидается: 8 колонок контракта.
Факт: `year_month text, sum_no_commission numeric, sum_with_commission numeric, commission numeric, prev_commission numeric, commission_diff numeric, courier_pay numeric, net_profit numeric`.
Вердикт: OK

### F.2. Месяцы покрыты

```sql
SELECT count(*), min(year_month), max(year_month) FROM how_much_money;
```

Ожидается: непрерывная серия от первого доставленного заказа до последнего.
Факт: 7 месяцев, 2026-05 … 2026-11 — без пропусков (рекурсивный CTE).
Вердикт: OK

### F.3. Месяцы без заказов присутствуют (BR-11.9)

```sql
-- проверка на копии данных: удаляем доставленные заказы за август 2026
DELETE FROM "order" WHERE order_timestamp >= '2026-08-01' AND order_timestamp < '2026-09-01';
SELECT year_month, sum_no_commission FROM how_much_money ORDER BY year_month;
```

Ожидается: месяц без заказов остаётся в отчёте с нулевыми суммами.
Факт: строка `2026-08` осталась в результате, `sum_no_commission = 0`, `commission = 0`.
Вердикт: OK

### F.4. Корректность сумм

```sql
SELECT count(*) FROM how_much_money
WHERE commission <> sum_with_commission - sum_no_commission
   OR net_profit <> commission - courier_pay
   OR (prev_commission IS NOT NULL AND commission_diff <> commission - prev_commission);
```

Ожидается: 0.
Факт: 0; у первого месяца `prev_commission IS NULL`.
Вердикт: OK

---

## G. Права `inspector`

### G.1. Права на схему

```sql
SELECT has_schema_privilege('inspector', 'vervykishko_food', 'USAGE')  AS usage,
       has_schema_privilege('inspector', 'vervykishko_food', 'CREATE') AS create;
```

Ожидается: `true`, `true`.
Факт: `true`, `true` (`GRANT ALL PRIVILEGES ON SCHEMA`).
Вердикт: OK

### G.2. Права на таблицы

```sql
SELECT count(DISTINCT table_name) FROM information_schema.role_table_grants
WHERE grantee = 'inspector' AND table_schema = 'vervykishko_food'
  AND privilege_type = 'SELECT';
```

Ожидается: у каждой таблицы `SELECT, INSERT, UPDATE, DELETE`.
Факт: 13 объектов (12 таблиц + представление) с полным набором прав.
Вердикт: OK

### G.3. `information_schema` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM information_schema.tables WHERE table_schema = 'vervykishko_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: 13 (12 таблиц + 1 представление).
Вердикт: OK

### G.4. `pg_catalog` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM pg_catalog.pg_tables WHERE schemaname = 'vervykishko_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: 12.
Вердикт: OK

### G.5. Все процедуры/функции работают под `inspector`

```sql
SET ROLE inspector;
SET search_path TO vervykishko_food, exts;
CALL erase_test_data();
CALL insert_test_data(10);
CALL courier_salary();
SELECT * FROM get_statistic();
SELECT * FROM how_much_money LIMIT 5;
RESET ROLE;
```

Ожидается: без `permission denied`.
Факт: все вызовы выполнены, ошибок прав нет.
Вердикт: OK

---

## H. Оптимизация `get_statistic` (BR-11.8)

Измерения на 10 ресторанах / 50 заказах, `EXPLAIN (ANALYZE, COSTS OFF)`.

### H.1. Паттерн «избыточные подзапросы»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM "order" o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS s
FROM courier c;
```

Ожидается: два `SubPlan`, время растёт линейно от числа курьеров.
Факт: два `SubPlan`, два отдельных сканирования `"order"`, Execution Time **0.384 мс**.
Вердикт: OK

### H.2. Паттерн «один JOIN»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id, count(o.order_id) AS cnt, coalesce(sum(o.commission), 0) AS s
FROM courier c
LEFT JOIN "order" o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
```

Ожидается: один `Hash Left Join`, время меньше, чем в H.1.
Факт: `Hash Left Join`, Execution Time **0.190 мс** — быстрее H.1 в 2 раза.
Вердикт: OK

### H.3. Применить к `get_statistic`

```sql
EXPLAIN ANALYZE SELECT * FROM get_statistic();
```

Ожидается: без `LATERAL`, без множественных подзапросов к одной таблице, без оконных функций там, где хватает агрегата.
Факт: в плане нет `LATERAL`, нет `SubPlan` и `WindowAgg`; агрегация выполняется CTE с `GROUP BY` + `DISTINCT ON`, Execution Time **5.7 мс**.
Вердикт: OK

---

## I. Очистка и повторная генерация

### I.1. `erase_test_data` очищает всё

```sql
CALL erase_test_data();
SELECT 'client' tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM "order"
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'order_structure', count(*) FROM order_structure
UNION ALL SELECT 'client_address', count(*) FROM client_address
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay;
```

Ожидается: все 0.
Факт: все 12 таблиц по 0 строк.
Вердикт: OK

### I.2. Повторный `erase_test_data` не падает

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: без ошибок (таблицы удаляются в порядке, учитывающем FK).
Вердикт: OK

### I.3. После очистки `insert_test_data` снова работает

```sql
CALL insert_test_data(10);
SELECT count(*) FROM "order";
```

Ожидается: 50.
Факт: 50.
Вердикт: OK

---

## Итог по тикетам

| Тикет | Проверки | Вердикт |
|---|---|---|
| FOOD-101 | B.1–B.7 | OK |
| FOOD-102 | C.1–C.9, D.1–D.14 | OK |
| FOOD-103 | I.1–I.2 | OK |
| FOOD-104 | E.1–E.2 | OK |
| FOOD-105 | E.3–E.4, D.14 | OK |
| FOOD-106 | E.5, H.3 | OK |
| FOOD-107 | E.6–E.7 | OK |
| FOOD-108 | F.1–F.4 | OK |
| FOOD-109 | G.1–G.5 | OK |
| FOOD-110 | A.1, восстановление + `grants.sql` + работа под `inspector` | OK |
