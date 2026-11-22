-- FOOD-104. Добавление блюда.
-- Ошибки формулируются для человека, который работает в интерфейсе:
-- без UUID, с указанием, что именно не так и что делать дальше.
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
DECLARE
    v_restaurant_name varchar(150);
    v_category_name varchar(100);
BEGIN
    IF p_name IS NULL OR btrim(p_name) = '' THEN
        RAISE EXCEPTION 'Блюдо не добавлено: название не может быть пустым'
            USING ERRCODE = 'check_violation',
                  HINT = 'Укажите название блюда, как его увидит клиент в меню.';
    END IF;

    IF p_description IS NULL OR btrim(p_description) = '' THEN
        RAISE EXCEPTION 'Блюдо не добавлено: описание обязательно'
            USING ERRCODE = 'check_violation',
                  HINT = 'Клиент не закажет блюдо без описания — укажите состав или особенности.';
    END IF;

    IF p_price IS NULL OR p_price < 0 OR p_price > 100000 THEN
        RAISE EXCEPTION 'Блюдо не добавлено: цена должна быть неотрицательной и не более 100000'
            USING ERRCODE = 'check_violation',
                  HINT = 'Проверьте цену: значение должно быть в рублях, например 350.00.';
    END IF;

    IF p_rating IS NOT NULL AND (p_rating < 0 OR p_rating > 5) THEN
        RAISE EXCEPTION 'Блюдо не добавлено: рейтинг должен быть от 0 до 5'
            USING ERRCODE = 'check_violation',
                  HINT = 'Рейтинг формируется отзывами; вручную допустимо 0..5 или NULL.';
    END IF;

    SELECT restaurant_name
    INTO v_restaurant_name
    FROM vervykishko_food.restaurant
    WHERE restaurant_id = p_restaurant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Блюдо не добавлено: ресторан не найден'
            USING ERRCODE = 'foreign_key_violation',
                  HINT = 'Выберите ресторан из справочника ресторанов и повторите добавление.';
    END IF;

    SELECT product_category_name
    INTO v_category_name
    FROM vervykishko_food.product_category
    WHERE product_category_id = p_product_category_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Блюдо не добавлено: категория не найдена'
            USING ERRCODE = 'foreign_key_violation',
                  HINT = 'Выберите категорию из справочника категорий блюд.';
    END IF;

    INSERT INTO vervykishko_food.product (
        product_name, product_category_id, price, restaurant_id,
        photo_url, rating, status, description
    )
    VALUES (
        btrim(p_name), p_product_category_id, p_price, p_restaurant_id,
        p_photo_url, p_rating, p_status, btrim(p_description)
    );
END;
$$;
