CREATE OR REPLACE FUNCTION vervykishko_food.get_statistic()
RETURNS TABLE (
    restaurant_name varchar,
    best_product_name varchar,
    total_amount numeric,
    avg_amount numeric,
    best_user varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH 
    -- 1. Считаем суммы по ресторанам (total и avg) для доставленных заказов
    restaurant_stats AS (
        SELECT 
            o.restaurant_id,
            SUM(o.total_amount) AS total_amount,
            AVG(o.total_amount) AS avg_amount
        FROM vervykishko_food."order" o
        WHERE o.status = 'доставлен'
        GROUP BY o.restaurant_id
    ),
    -- 2. Ищем самое покупаемое блюдо для каждого ресторана
    -- Используем DISTINCT ON, чтобы взять одно (случайное при равенстве)
    best_product AS (
        SELECT DISTINCT ON (p.restaurant_id)
            p.restaurant_id,
            p.product_name
        FROM vervykishko_food.product p
        JOIN vervykishko_food.order_structure os ON p.product_id = os.product_id
        JOIN vervykishko_food."order" o ON os.order_id = o.order_id
        WHERE o.status = 'доставлен'
        GROUP BY p.restaurant_id, p.product_id, p.product_name
        ORDER BY p.restaurant_id, SUM(os.quantity) DESC, random()
    ),
    -- 3. Ищем самого частого клиента для каждого ресторана
    -- Используем DISTINCT ON, чтобы взять одного (случайного при равенстве)
    best_client AS (
        SELECT DISTINCT ON (o.restaurant_id)
            o.restaurant_id,
            c.login
        FROM vervykishko_food."order" o
        JOIN vervykishko_food.client c ON o.client_id = c.client_id
        WHERE o.status = 'доставлен'
        GROUP BY o.restaurant_id, c.client_id, c.login
        ORDER BY o.restaurant_id, COUNT(o.order_id) DESC, random()
    )
    -- 4. Собираем всё вместе
    SELECT 
        r.restaurant_name,
        bp.product_name,
        rs.total_amount,
        rs.avg_amount,
        bc.login
    FROM vervykishko_food.restaurant r
    JOIN restaurant_stats rs ON r.restaurant_id = rs.restaurant_id
    LEFT JOIN best_product bp ON r.restaurant_id = bp.restaurant_id
    LEFT JOIN best_client bc ON r.restaurant_id = bc.restaurant_id;
END;
$$;