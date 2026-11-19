CREATE OR REPLACE PROCEDURE vervykishko_food.insert_test_data(value int)
LANGUAGE plpgsql
AS $$
DECLARE
    v_clients uuid[];
    v_couriers uuid[];
    v_categories uuid[];
    v_restaurants uuid[];
    v_addresses uuid[];
    v_products uuid[];
    i int;
    j int;
    v_rest_id uuid;
    v_client_id uuid;
    v_address_id uuid;
    v_order_id uuid;
    v_order_client_id uuid;
    v_product_id uuid;
    v_category_id uuid;
    v_order_amount numeric;
    v_commission numeric;
    v_total_amount numeric;
    v_order_total numeric;
    v_quantity numeric;
    v_rand_idx int;
    v_rand_date timestamp;
    v_rand_date_end timestamp;
    v_courier_id uuid;
    v_status vervykishko_food.courier_status;
    v_hire_date date;
    v_dismissal_date date;
    v_coefficient numeric;
    v_work_start time;
    v_work_end time;
    v_pay_type vervykishko_food.payment_type;
    v_pay_year int;
    v_pay_month int;
    v_month_start date;
    v_month_end date;
    v_sum_commission numeric;
    v_courier_coeff numeric;
    v_new_coeff numeric;
    v_delivery_count int;
    v_review_counter int := 0;
    v_unique_suffix text;
BEGIN
    v_unique_suffix := to_char(clock_timestamp(), 'YYMMDDHH24MISSUS') || '_' || floor(random() * 10000)::text;

    -- ==========================================
    -- 1. СПРАВОЧНИКИ БЕЗ FK
    -- ==========================================
    FOR i IN 1..value LOOP
        INSERT INTO vervykishko_food.product_category (product_category_name) VALUES ('Категория_' || i || '_' || v_unique_suffix);
    END LOOP;
    SELECT array_agg(product_category_id) INTO v_categories FROM vervykishko_food.product_category WHERE product_category_name LIKE '%' || v_unique_suffix;

    -- BR-11.7: value * 5 адресов, из них value — под рестораны, value * 4 — под клиентов
    FOR i IN 1..(value * 5) LOOP
        INSERT INTO vervykishko_food.address (street, house_number, apartment_office)
        VALUES ('Улица_' || i || '_' || v_unique_suffix, 'Дом_' || i, CASE WHEN random() < 0.5 THEN 'Кв_' || i ELSE NULL END);
    END LOOP;
    SELECT array_agg(address_id) INTO v_addresses FROM vervykishko_food.address WHERE street LIKE '%' || v_unique_suffix;

    FOR i IN 1..value LOOP
        IF i = 1 THEN
            v_status := 'свободен'; v_dismissal_date := NULL;   -- BR-6.6: минимум один активный курьер
        ELSE
            IF random() < 0.2 THEN
                v_status := 'уволен'; v_dismissal_date := current_date - (random() * 100)::int;
            ELSE
                v_status := (enum_range(NULL::vervykishko_food.courier_status))[ceil(random() * 3)::int]; v_dismissal_date := NULL;
            END IF;
        END IF;
        v_hire_date := current_date - (random() * 180)::int;
        IF v_status = 'уволен' THEN
            v_dismissal_date := v_hire_date + (random() * 50)::int;
            IF v_dismissal_date > current_date THEN v_dismissal_date := current_date; END IF;
        END IF;
        v_coefficient := round((0.1 + random() * 0.4)::numeric, 1);

        INSERT INTO vervykishko_food.courier (fio, phone_number, status, hire_date, dismissal_date, coefficient)
        VALUES ('Курьер_' || i || '_' || v_unique_suffix, '+7900' || lpad(i::text, 7, '0') || substr(md5(random()::text), 1, 4), v_status, v_hire_date, v_dismissal_date, v_coefficient);
    END LOOP;
    SELECT array_agg(courier_id) INTO v_couriers FROM vervykishko_food.courier WHERE fio LIKE '%' || v_unique_suffix;

    -- ==========================================
    -- 2. СПРАВОЧНИКИ С FK
    -- ==========================================
    -- Адреса ресторанов — первые value элементов массива адресов (BR-11.7)
    FOR i IN 1..value LOOP
        -- График: открытие 08:00–10:00, работа 4–11 часов, закрытие строго до полуночи (BR-4.4)
        v_work_start := '08:00'::time + floor(random() * 3)::int * interval '1 hour';
        v_work_end := v_work_start + (4 + floor(random() * 8))::int * interval '1 hour';
        -- rating намеренно NULL: агрегат поддерживается триггером rating_change (FOOD-105)
        INSERT INTO vervykishko_food.restaurant (restaurant_name, address_id, description, work_start, work_end, company_details, rating, status)
        VALUES ('Ресторан_' || i || '_' || v_unique_suffix, v_addresses[i], 'Описание ресторана ' || i, v_work_start, v_work_end, 'ИНН ' || (1000000000 + i), NULL, 'активен');
    END LOOP;
    SELECT array_agg(restaurant_id) INTO v_restaurants FROM vervykishko_food.restaurant WHERE restaurant_name LIKE '%' || v_unique_suffix;

    FOR i IN 1..value LOOP
        INSERT INTO vervykishko_food.client (login, password, phone_number)
        VALUES ('client_' || i || '_' || v_unique_suffix, md5(random()::text), '+7911' || lpad(i::text, 7, '0') || substr(md5(random()::text), 1, 4));
    END LOOP;
    SELECT array_agg(client_id) INTO v_clients FROM vervykishko_food.client WHERE login LIKE '%' || v_unique_suffix;

    -- ==========================================
    -- 3. M:N СВЯЗИ
    -- ==========================================
    -- Адреса клиентов — элементы массива с value+1 по value*5 (BR-11.7)
    FOR i IN 1..value LOOP
        FOR j IN 1..(1 + (random() * 2)::int) LOOP
            v_rand_idx := value + 1 + floor(random() * (value * 4 - 1))::int;
            v_address_id := v_addresses[v_rand_idx];
            IF NOT EXISTS (SELECT 1 FROM vervykishko_food.client_address WHERE client_id = v_clients[i] AND address_id = v_address_id) THEN
                INSERT INTO vervykishko_food.client_address (client_id, address_id) VALUES (v_clients[i], v_address_id);
            END IF;
        END LOOP;
    END LOOP;

    -- ==========================================
    -- 4. БЛЮДА
    -- ==========================================
    FOR i IN 1..(value * 5) LOOP
        v_rest_id := v_restaurants[1 + floor(random() * value)::int];
        v_category_id := v_categories[1 + floor(random() * value)::int];
        -- rating намеренно NULL: агрегат поддерживается триггером rating_change (FOOD-105)
        INSERT INTO vervykishko_food.product (product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
        VALUES ('Блюдо_' || i || '_' || v_unique_suffix, v_category_id, round((100 + random() * 900)::numeric, 2), v_rest_id,
                CASE WHEN random() < 0.5 THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg' ELSE NULL END,
                NULL, 'доступно', 'Описание блюда ' || i);
    END LOOP;
    SELECT array_agg(product_id) INTO v_products FROM vervykishko_food.product WHERE product_name LIKE '%' || v_unique_suffix;

    -- ==========================================
    -- 5. ЗАКАЗЫ (BR-11.7: value * 5)
    -- ==========================================
    FOR i IN 1..(value * 5) LOOP
        v_client_id := v_clients[1 + floor(random() * value)::int];
        v_rest_id := v_restaurants[1 + floor(random() * value)::int];
        -- BR-7.4: адрес доставки обязан принадлежать клиенту (D.6)
        SELECT address_id INTO v_address_id FROM vervykishko_food.client_address WHERE client_id = v_client_id LIMIT 1;
        IF v_address_id IS NULL THEN
            -- У клиента ещё нет адреса — привязываем адрес из клиентского диапазона
            v_rand_idx := value + 1 + floor(random() * (value * 4 - 1))::int;
            v_address_id := v_addresses[v_rand_idx];
            INSERT INTO vervykishko_food.client_address (client_id, address_id)
            VALUES (v_client_id, v_address_id)
            ON CONFLICT DO NOTHING;
        END IF;

        SELECT courier_id INTO v_courier_id FROM vervykishko_food.courier WHERE status != 'уволен' AND fio LIKE '%' || v_unique_suffix ORDER BY random() LIMIT 1;
        IF v_courier_id IS NULL THEN v_courier_id := v_couriers[1]; END IF;

        v_order_amount := round((1000 + random() * 4000)::numeric, 2);
        v_commission := round(v_order_amount * 0.10, 2);
        v_total_amount := round(v_order_amount + v_commission, 2);
        v_rand_date := localtimestamp - (random() * 180)::int * interval '1 day';

        IF random() < 0.8 THEN
            v_rand_date_end := v_rand_date + (random() * 2)::int * interval '1 hour';
            INSERT INTO vervykishko_food."order" (client_id, restaurant_id, courier_id, address_id, order_timestamp, delivery_timestamp, order_amount, commission, total_amount, status, pay_status, description)
            VALUES (v_client_id, v_rest_id, v_courier_id, v_address_id, v_rand_date, v_rand_date_end, v_order_amount, v_commission, v_total_amount, 'доставлен', 'оплачен', 'Тестовый заказ');
        ELSE
            INSERT INTO vervykishko_food."order" (client_id, restaurant_id, courier_id, address_id, order_timestamp, delivery_timestamp, order_amount, commission, total_amount, status, pay_status, description)
            VALUES (v_client_id, v_rest_id, v_courier_id, v_address_id, v_rand_date, NULL, v_order_amount, v_commission, v_total_amount, 'создан', 'ожидает', 'Тестовый заказ');
        END IF;
    END LOOP;

    -- ==========================================
    -- 6. СОСТАВ ЗАКАЗА, ПЛАТЕЖИ, ОТЗЫВЫ
    -- ==========================================
    FOR v_order_id IN (SELECT order_id FROM vervykishko_food."order" o JOIN vervykishko_food.client c ON o.client_id = c.client_id WHERE c.login LIKE '%' || v_unique_suffix) LOOP
        -- Берём атрибуты именно этого заказа: ресторан, клиент и сумму
        SELECT restaurant_id, client_id, total_amount
          INTO v_rest_id, v_order_client_id, v_order_total
          FROM vervykishko_food."order"
         WHERE order_id = v_order_id;

        -- BR-7.3: все блюда из ресторана заказа
        FOR j IN 1..(1 + (random() * 4)::int) LOOP
            SELECT product_id INTO v_product_id FROM vervykishko_food.product WHERE restaurant_id = v_rest_id ORDER BY random() LIMIT 1;
            IF v_product_id IS NOT NULL THEN
                IF NOT EXISTS (SELECT 1 FROM vervykishko_food.order_structure WHERE order_id = v_order_id AND product_id = v_product_id) THEN
                    v_quantity := round((1 + random() * 3)::numeric, 2);
                    INSERT INTO vervykishko_food.order_structure (order_id, product_id, quantity) VALUES (v_order_id, v_product_id, v_quantity);
                END IF;
            END IF;
        END LOOP;

        -- BR-8.4: сумма попытки оплаты = total_amount именно этого заказа
        v_pay_type := (enum_range(NULL::vervykishko_food.payment_type))[ceil(random() * 3)::int];
        INSERT INTO vervykishko_food.payment (order_id, payment_type, amount, transaction_id, transaction_timestamp, status)
        VALUES (v_order_id, v_pay_type, v_order_total, md5(random()::text) || v_unique_suffix, localtimestamp, 'успех');

        -- BR-11.7: ровно value * 5 отзывов — по одному на заказ, поочерёдно на ресторан и на блюдо.
        -- BR-9.2: автор отзыва — клиент этого заказа.
        IF v_review_counter % 2 = 0 THEN
            INSERT INTO vervykishko_food.review (client_id, entity_id, entity_type, order_id, description, photo_url, rating)
            VALUES (v_order_client_id, v_rest_id, 'ресторан', v_order_id, 'Отзыв на ресторан', NULL, ceil(random() * 5));
        ELSE
            SELECT product_id INTO v_product_id FROM vervykishko_food.order_structure WHERE order_id = v_order_id LIMIT 1;
            IF v_product_id IS NULL THEN
                INSERT INTO vervykishko_food.review (client_id, entity_id, entity_type, order_id, description, photo_url, rating)
                VALUES (v_order_client_id, v_rest_id, 'ресторан', v_order_id, 'Отзыв на ресторан', NULL, ceil(random() * 5));
            ELSE
                INSERT INTO vervykishko_food.review (client_id, entity_id, entity_type, order_id, description, photo_url, rating)
                VALUES (v_order_client_id, v_product_id, 'блюдо', v_order_id, 'Отзыв на блюдо', NULL, ceil(random() * 5));
            END IF;
        END IF;
        v_review_counter := v_review_counter + 1;
    END LOOP;

    -- ==========================================
    -- 7. ВЫПЛАТЫ КУРЬЕРАМ ЗА 6 МЕСЯЦЕВ (BR-10.2, BR-10.7)
    -- ==========================================
    FOR i IN 0..5 LOOP
        v_month_start := date_trunc('month', current_date - (i || ' months')::interval);
        -- Правая граница месяца — исключающая: начало следующего месяца
        v_month_end := (v_month_start + interval '1 month')::date;
        v_pay_year := extract(year from v_month_start);
        v_pay_month := extract(month from v_month_start);
        FOR v_courier_id IN (SELECT courier_id FROM vervykishko_food.courier WHERE fio LIKE '%' || v_unique_suffix) LOOP
            SELECT COALESCE(SUM(commission), 0) INTO v_sum_commission FROM vervykishko_food."order"
            WHERE courier_id = v_courier_id AND status = 'доставлен' AND order_timestamp >= v_month_start AND order_timestamp < v_month_end;
            SELECT coefficient INTO v_courier_coeff FROM vervykishko_food.courier WHERE courier_id = v_courier_id;
            INSERT INTO vervykishko_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (v_pay_year, v_pay_month, v_courier_id, round(v_sum_commission * v_courier_coeff, 2), v_courier_coeff);
        END LOOP;
    END LOOP;

    -- Коэффициент на следующий месяц — по количеству доставок за текущий месяц (BR-10.2)
    FOR v_courier_id IN (SELECT courier_id FROM vervykishko_food.courier WHERE status != 'уволен' AND fio LIKE '%' || v_unique_suffix) LOOP
        SELECT count(*) INTO v_delivery_count FROM vervykishko_food."order"
        WHERE courier_id = v_courier_id AND status = 'доставлен'
          AND order_timestamp >= date_trunc('month', current_date)
          AND order_timestamp < date_trunc('month', current_date) + interval '1 month';
        IF v_delivery_count <= 150 THEN v_new_coeff := 0.1;
        ELSIF v_delivery_count <= 250 THEN v_new_coeff := 0.2;
        ELSIF v_delivery_count <= 500 THEN v_new_coeff := 0.3;
        ELSE v_new_coeff := 0.5;
        END IF;
        UPDATE vervykishko_food.courier SET coefficient = v_new_coeff WHERE courier_id = v_courier_id;
    END LOOP;
END;
$$;
