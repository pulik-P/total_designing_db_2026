CREATE OR REPLACE PROCEDURE vervykishko_food.add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_rating numeric,
    p_status vervykishko_food.product_status,
    p_description text,
    p_photo_url text DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM vervykishko_food.restaurant WHERE restaurant_id = p_restaurant_id) THEN
        RAISE EXCEPTION 'Ресторан с ID % не существует', p_restaurant_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM vervykishko_food.product_category WHERE product_category_id = p_product_category_id) THEN
        RAISE EXCEPTION 'Категория с ID % не существует', p_product_category_id;
    END IF;

    IF p_price < 0 THEN
        RAISE EXCEPTION 'Цена не может быть отрицательной';
    END IF;

    INSERT INTO vervykishko_food.product (
        product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description
    ) VALUES (
        p_name, p_product_category_id, p_price, p_restaurant_id, p_photo_url, p_rating, p_status, p_description
    );
END;
$$;