-- FOOD-106. Статистика по ресторанам.
-- BR-11.8: без подзапросов на каждую строку, без оконных функций и без DISTINCT ON.
-- Топ-1 выбирается агрегатом array_agg(...)[1] — один проход по данным.
--
-- random() используется осознанно и только как tie-break: по контракту
-- («если таких несколько — случайное») при равенстве количества нужно выбрать
-- любое блюдо/клиента. random() стоит ВТОРЫМ ключом сортировки внутри array_agg,
-- поэтому влияет только на равные значения и не мешает использовать агрегаты.
CREATE OR REPLACE FUNCTION vervykishko_food.get_statistic()
RETURNS TABLE (
    restaurant_name varchar,
    best_product_name varchar,
    total_amount numeric,
    avg_amount numeric,
    best_user varchar
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    WITH delivered AS (
        SELECT o.order_id, o.restaurant_id, o.client_id, o.total_amount
        FROM vervykishko_food."order" o
        WHERE o.status = 'доставлен'
    ),
    -- Выручка ресторана: один проход по доставленным заказам
    restaurant_stats AS (
        SELECT d.restaurant_id,
               SUM(d.total_amount) AS total_amount,
               AVG(d.total_amount) AS avg_amount
        FROM delivered d
        GROUP BY d.restaurant_id
    ),
    -- Продажи по блюдам внутри ресторана
    product_sales AS (
        SELECT d.restaurant_id,
               p.product_name,
               SUM(os.quantity) AS quantity
        FROM delivered d
        JOIN vervykishko_food.order_structure os ON os.order_id = d.order_id
        JOIN vervykishko_food.product p ON p.product_id = os.product_id
        GROUP BY d.restaurant_id, p.product_name
    ),
    -- Топ-1 блюдо: сортировка внутри array_agg, берём первый элемент
    best_product AS (
        SELECT ps.restaurant_id,
               (array_agg(ps.product_name ORDER BY ps.quantity DESC, random()))[1] AS product_name
        FROM product_sales ps
        GROUP BY ps.restaurant_id
    ),
    -- Покупки клиентов внутри ресторана
    client_purchases AS (
        SELECT d.restaurant_id,
               c.login,
               COUNT(*) AS orders_count
        FROM delivered d
        JOIN vervykishko_food.client c ON c.client_id = d.client_id
        GROUP BY d.restaurant_id, c.login
    ),
    -- Топ-1 клиент
    best_client AS (
        SELECT cp.restaurant_id,
               (array_agg(cp.login ORDER BY cp.orders_count DESC, random()))[1] AS login
        FROM client_purchases cp
        GROUP BY cp.restaurant_id
    )
    SELECT r.restaurant_name,
           bp.product_name,
           rs.total_amount,
           rs.avg_amount,
           bc.login
    FROM vervykishko_food.restaurant r
    JOIN restaurant_stats rs ON rs.restaurant_id = r.restaurant_id
    LEFT JOIN best_product bp ON bp.restaurant_id = r.restaurant_id
    LEFT JOIN best_client bc ON bc.restaurant_id = r.restaurant_id;
END;
$$;
