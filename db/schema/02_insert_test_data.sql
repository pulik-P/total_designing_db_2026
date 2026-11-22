-- FOOD-102. Генератор тестовых данных.
-- Осмысленные кириллические значения (ФИО, блюда, улицы, описания), без цифр
-- и латинских префиксов. Технические приёмы — из samples/all_examples.sql:
--   §3 enum_range(), §4 даты за 180 дней, §5 числа в диапазонах CHECK,
--   §6 md5, §7 массивы ID вместо сканов в цикле, §8 M:N, §9 generate_series,
--   §10 генератор не вызывает бизнес-функции (рейтинги считаются напрямую),
--   §11 порядок заполнения, §12 чек-лист ловушек.
-- BR-11.7: client/courier/product_category/restaurant — value,
--          address/product/order/review/payment — value * 5.

CREATE OR REPLACE PROCEDURE vervykishko_food.insert_test_data(value int)
LANGUAGE plpgsql
AS $$
DECLARE
    v_surnames text[] := ARRAY['Иванов', 'Петров', 'Сидоров', 'Кузнецов', 'Смирнов',
                               'Попов', 'Васильев', 'Соколов', 'Михайлов', 'Новиков',
                               'Фёдоров', 'Морозов', 'Волков', 'Алексеев', 'Лебедев',
                               'Семёнов', 'Егоров', 'Павлов', 'Козлов', 'Степанов'];
    v_first_names text[] := ARRAY['Алексей', 'Дмитрий', 'Сергей', 'Андрей', 'Иван',
                                  'Михаил', 'Николай', 'Павел', 'Роман', 'Владимир',
                                  'Егор', 'Артём', 'Максим', 'Кирилл', 'Олег',
                                  'Виктор', 'Григорий', 'Тимофей', 'Фёдор', 'Борис'];
    v_middle_names text[] := ARRAY['Алексеевич', 'Дмитриевич', 'Сергеевич', 'Андреевич',
                                   'Иванович', 'Михайлович', 'Николаевич', 'Павлович',
                                   'Романович', 'Владимирович'];
    v_streets text[] := ARRAY['Ленина', 'Гагарина', 'Мира', 'Садовая', 'Лесная',
                              'Центральная', 'Победы', 'Советская', 'Молодёжная',
                              'Школьная', 'Набережная', 'Полевая', 'Заречная',
                              'Солнечная', 'Северная'];
    v_category_names text[] := ARRAY['Супы', 'Салаты', 'Гарниры', 'Напитки', 'Десерты',
                                 'Закуски', 'Гриль', 'Выпечка', 'Морепродукты', 'Каши'];
    v_dish_names text[] := ARRAY['Борщ с говядиной', 'Салат Цезарь', 'Сырники со сметаной',
                                 'Плов с бараниной', 'Паста карбонара', 'Котлета по-киевски',
                                 'Омлет с сыром', 'Гречка с грибами', 'Уха по-домашнему',
                                 'Пельмени сибирские', 'Шашлык из свинины', 'Блинчики с творогом',
                                 'Стейк из говядины', 'Куриный суп с лапшой', 'Роллы Филадельфия',
                                 'Картофельное пюре с котлетой'];
    v_restaurant_names text[] := ARRAY['Тёплый вечер', 'Синий кит', 'Домашняя кухня',
                                       'Золотая вилка', 'Уютный двор', 'Вкусный угол',
                                       'Лесная поляна', 'Солнечный берег', 'Старый город',
                                       'Белый парус'];
    v_descriptions text[] := ARRAY[
        'Готовим на свежих продуктах, подаём быстро и горячим.',
        'Домашняя кухня без полуфабрикатов и лишних добавок.',
        'Большие порции, понятный состав и честные цены.',
        'Каждое блюдо готовится после заказа, не разогреваем.',
        'Работаем с местными поставщиками и меняем меню по сезону.',
        'Уютный зал, вежливые курьеры и аккуратная упаковка.',
        'Классические рецепты, которые нравятся всей семье.',
        'Свежая выпечка каждое утро и ароматный кофе.',
        'Острые соусы собственного приготовления и щедрые порции.',
        'Быстрая доставка по городу и бережная упаковка.',
        'Меню обновляем каждый месяц, хиты остаются.',
        'Готовим на открытом огне и подаём с соусом.',
        'Работаем с фермерскими продуктами без заморозки.',
        'Любим простые рецепты и понятные ингредиенты.',
        'Принимаем заказы до полуночи, курьеры на связи.',
        'Порции рассчитаны на взрослого человека.',
        'Все блюда готовятся из охлаждённого мяса.',
        'Вегетарианские позиции готовим отдельно.',
        'Упаковка выдерживает дорогу и не промокает.',
        'Детское меню без острого и без красителей.'];
    v_order_notes text[] := ARRAY[
        'Доставить к подъезду, позвонить за десять минут.',
        'Без лука, соус отдельно.',
        'Позвонить в домофон, поднять на третий этаж.',
        'Оставить у двери, не звонить.',
        'Приборы на две персоны, салфетки.',
        'Добавить острый соус и хлеб.',
        'Доставить к офису на ресепшен.',
        'Упаковать отдельно горячее и салат.',
        'Позвонить за двадцать минут до прибытия.',
        'Без соли, пожалуйста.',
        'Доставить после восемнадцати часов.',
        'Код домофона сообщить по телефону.',
        'Положить приборы и салфетки.',
        'Нарезать на порционные куски.',
        'Без острого соуса, остальное как обычно.',
        'Позвонить, если шлагбаум закрыт.',
        'Доставить к чёрному ходу.',
        'Оставить у консьержа.',
        'Добавить соус и хлеб к заказу.',
        'Позвонить перед выездом курьера.'];
    v_review_notes text[] := ARRAY[
        'Всё приехало горячим и аккуратно упаковано.',
        'Порция большая, вкус насыщенный, закажем ещё.',
        'Курьер приехал вовремя и был вежлив.',
        'Ожидание чуть дольше обычного, но еда того стоила.',
        'Состав соответствует описанию, всё свежее.',
        'Понравилось, что соус положили отдельно.',
        'В этот раз блюдо показалось чуть пресным.',
        'Отличное соотношение цены и качества.',
        'Заказ собрали аккуратно, ничего не разлилось.',
        'Понравилось, что позвонили заранее.',
        'Порция меньше, чем ожидали, но вкусно.',
        'Соус оказался острее, чем написано.',
        'Доставили быстрее заявленного времени.',
        'Вежливый курьер, помог донести до двери.',
        'Всё соответствует меню, будем заказывать ещё.',
        'Еда остыла в дороге, но вкус хороший.'];

    v_clients uuid[] := '{}';
    v_couriers uuid[] := '{}';
    v_category_ids uuid[] := '{}';
    v_restaurants uuid[] := '{}';
    v_addresses uuid[] := '{}';
    v_active_couriers uuid[] := '{}';
    v_product_ids uuid[];
    v_id uuid;

    i int;
    j int;
    v_idx int;
    v_idx2 int;
    v_idx3 int;
    v_login text;
    v_phone text;
    v_inn varchar(12);
    v_ogrn varchar(15);
    v_rest_id uuid;
    v_client_id uuid;
    v_address_id uuid;
    v_courier_id uuid;
    v_order_id uuid;
    v_product_id uuid;
    v_category_id uuid;
    v_order_amount numeric;
    v_commission numeric;
    v_total_amount numeric;
    v_order_ts timestamp;
    v_delivery_ts timestamp;
    v_status vervykishko_food.order_status;
    v_courier_status vervykishko_food.courier_status;
    v_payment_type vervykishko_food.payment_type;
    v_payment_status vervykishko_food.payment_status;
    v_success boolean;
    v_coefficient numeric;
    v_hire_date date;
    v_dismissal_date date;
    v_work_start time;
    v_work_end time;
    v_reviews_left int;
    v_review_type vervykishko_food.review_entity_type;
    v_month_start date;
    v_month_end date;
    v_pay_year int;
    v_pay_month int;
    v_sum_commission numeric;
    v_delivery_count int;
    v_new_coefficient numeric;
BEGIN
    IF value < 1 THEN
        RAISE EXCEPTION 'Параметр value должен быть положительным, получено %', value;
    END IF;

    -- Категории: value уникальных названий
    FOR i IN 1..value LOOP
        INSERT INTO vervykishko_food.product_category (product_category_name)
        VALUES (v_category_names[1 + (i - 1) % array_length(v_category_names, 1)])
        RETURNING product_category_id INTO v_id;
        v_category_ids := array_append(v_category_ids, v_id);
    END LOOP;

    -- Адреса: value * 5 (value под рестораны, value * 4 под клиентов)
    FOR i IN 1..(value * 5) LOOP
        INSERT INTO vervykishko_food.address (street, house_number, apartment_office)
        VALUES (
            v_streets[1 + floor(random() * array_length(v_streets, 1))::int],
            (1 + floor(random() * 200))::text,
            CASE WHEN random() < 0.5 THEN (1 + floor(random() * 300))::text ELSE NULL END
        )
        RETURNING address_id INTO v_id;
        v_addresses := array_append(v_addresses, v_id);
    END LOOP;

    -- Курьеры: ФИО раздельно (1НФ), начальный коэффициент 0.1 (BR-6.5)
    FOR i IN 1..value LOOP
        v_hire_date := current_date - (random() * 180)::int;

        IF i = 1 THEN
            v_courier_status := 'свободен';       -- BR-6.6
            v_dismissal_date := NULL;
        ELSE
            v_courier_status := (enum_range(NULL::vervykishko_food.courier_status))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.courier_status)))::int];

            IF v_courier_status = 'уволен' THEN
                v_dismissal_date := v_hire_date + (random() * (current_date - v_hire_date + 1))::int;
            ELSE
                v_dismissal_date := NULL;
            END IF;
        END IF;

        v_coefficient := 0.10;

        LOOP
            v_phone := '+7' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM vervykishko_food.courier WHERE phone_number = v_phone);
        END LOOP;

        INSERT INTO vervykishko_food.courier (
            last_name, first_name, middle_name, phone_number, status,
            hire_date, dismissal_date, coefficient
        )
        VALUES (
            v_surnames[1 + floor(random() * array_length(v_surnames, 1))::int],
            v_first_names[1 + floor(random() * array_length(v_first_names, 1))::int],
            v_middle_names[1 + floor(random() * array_length(v_middle_names, 1))::int],
            v_phone, v_courier_status, v_hire_date, v_dismissal_date, v_coefficient
        )
        RETURNING courier_id INTO v_id;
        v_couriers := array_append(v_couriers, v_id);
        IF v_courier_status <> 'уволен' THEN
            v_active_couriers := array_append(v_active_couriers, v_id);
        END IF;
    END LOOP;

    -- Рестораны: реквизиты раздельно (1НФ), описание обязательно
    FOR i IN 1..value LOOP
        v_work_start := '08:00'::time + floor(random() * 3)::int * interval '1 hour';
        v_work_end := v_work_start + (4 + floor(random() * 8))::int * interval '1 hour';

        LOOP
            v_inn := lpad(floor(random() * 10000000000)::bigint::text, 10, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM vervykishko_food.restaurant WHERE inn = v_inn);
        END LOOP;
        LOOP
            v_ogrn := lpad(floor(random() * 10000000000000)::bigint::text, 13, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM vervykishko_food.restaurant WHERE ogrn = v_ogrn);
        END LOOP;

        v_idx := 1 + floor(random() * array_length(v_descriptions, 1))::int;
        v_idx2 := 1 + ((v_idx - 1 + 1 + floor(random() * (array_length(v_descriptions, 1) - 1))::int) % array_length(v_descriptions, 1));

        INSERT INTO vervykishko_food.restaurant (
            restaurant_name, address_id, description, work_start, work_end,
            inn, ogrn, bank_account, rating, status
        )
        VALUES (
            v_restaurant_names[1 + floor(random() * array_length(v_restaurant_names, 1))::int],
            v_addresses[i],
            v_descriptions[v_idx] || ' ' || v_descriptions[v_idx2],
            v_work_start, v_work_end,
            v_inn, v_ogrn,
            lpad(floor(random() * 100000000000000000000)::numeric::text, 20, '0'),
            NULL,
            (enum_range(NULL::vervykishko_food.restaurant_status))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.restaurant_status)))::int]
        )
        RETURNING restaurant_id INTO v_id;
        v_restaurants := array_append(v_restaurants, v_id);
    END LOOP;

    -- Клиенты: логин уникален (BR-2.2)
    FOR i IN 1..value LOOP
        v_login := lower(v_surnames[1 + floor(random() * array_length(v_surnames, 1))::int]);
        WHILE EXISTS (SELECT 1 FROM vervykishko_food.client WHERE login = v_login) LOOP
            v_login := v_login
                       || lower(substr(v_first_names[1 + floor(random() * array_length(v_first_names, 1))::int], 1, 1));
        END LOOP;

        LOOP
            v_phone := '+7' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM vervykishko_food.client WHERE phone_number = v_phone);
        END LOOP;

        INSERT INTO vervykishko_food.client (login, password, phone_number)
        VALUES (v_login, md5(random()::text), v_phone)
        RETURNING client_id INTO v_id;
        v_clients := array_append(v_clients, v_id);
    END LOOP;

    -- client_address: 1..3 адреса клиента из клиентского диапазона
    FOR i IN 1..value LOOP
        FOR j IN 1..(1 + floor(random() * 3)::int) LOOP
            v_address_id := v_addresses[value + 1 + floor(random() * (value * 4))::int];
            INSERT INTO vervykishko_food.client_address (client_id, address_id)
            VALUES (v_clients[i], v_address_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    -- Блюда
    FOR i IN 1..(value * 5) LOOP
        v_rest_id := v_restaurants[1 + floor(random() * value)::int];
        v_category_id := v_category_ids[1 + floor(random() * value)::int];

        v_idx := 1 + floor(random() * array_length(v_descriptions, 1))::int;
        v_idx2 := 1 + ((v_idx - 1 + 1 + floor(random() * (array_length(v_descriptions, 1) - 1))::int) % array_length(v_descriptions, 1));

        INSERT INTO vervykishko_food.product (
            product_name, product_category_id, price, restaurant_id,
            photo_url, rating, status, description
        )
        VALUES (
            v_dish_names[1 + floor(random() * array_length(v_dish_names, 1))::int],
            v_category_id,
            round((100 + random() * 4900)::numeric, 2),
            v_rest_id,
            CASE WHEN random() < 0.5
                 THEN 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
                 ELSE NULL END,
            NULL,
            (enum_range(NULL::vervykishko_food.product_status))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.product_status)))::int],
            v_descriptions[v_idx] || ' ' || v_descriptions[v_idx2]
        );
    END LOOP;

    -- §7: массивы ID собираем один раз
    DROP TABLE IF EXISTS tmp_product_ids;
    CREATE TEMP TABLE tmp_product_ids ON COMMIT DROP AS
        SELECT restaurant_id, array_agg(product_id ORDER BY product_id) AS ids
        FROM vervykishko_food.product
        GROUP BY restaurant_id;

    DROP TABLE IF EXISTS tmp_client_addresses;
    CREATE TEMP TABLE tmp_client_addresses ON COMMIT DROP AS
        SELECT client_id, array_agg(address_id ORDER BY address_id) AS ids
        FROM vervykishko_food.client_address
        GROUP BY client_id;

    -- Заказы
    FOR i IN 1..(value * 5) LOOP
        v_client_id := v_clients[1 + floor(random() * value)::int];
        v_rest_id := v_restaurants[1 + floor(random() * value)::int];
        v_courier_id := v_active_couriers[1 + floor(random() * cardinality(v_active_couriers))::int];

        SELECT ids[1 + floor(random() * cardinality(ids))::int]
        INTO v_address_id
        FROM tmp_client_addresses
        WHERE client_id = v_client_id;

        v_order_amount := round((1000 + random() * 9000)::numeric, 2);
        v_commission := round(v_order_amount * 0.10, 2);
        v_total_amount := round(v_order_amount + v_commission, 2);
        v_order_ts := localtimestamp - (random() * 180)::int * interval '1 day'
                                  - (random() * 86400)::int * interval '1 second';

        IF random() < 0.6 THEN
            v_status := 'доставлен';
        ELSE
            v_status := (enum_range(NULL::vervykishko_food.order_status))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.order_status)))::int];
        END IF;

        IF v_status = 'доставлен' THEN
            v_delivery_ts := v_order_ts + (15 + random() * 90)::int * interval '1 minute';
        ELSE
            v_delivery_ts := NULL;
        END IF;

        v_idx := 1 + floor(random() * array_length(v_order_notes, 1))::int;
        v_idx2 := 1 + ((v_idx - 1 + 1 + floor(random() * (array_length(v_order_notes, 1) - 1))::int) % array_length(v_order_notes, 1));

        INSERT INTO vervykishko_food."order" (
            client_id, restaurant_id, courier_id, address_id,
            order_timestamp, delivery_timestamp, order_amount,
            status, pay_status, description
        )
        VALUES (
            v_client_id, v_rest_id, v_courier_id, v_address_id,
            v_order_ts, v_delivery_ts, v_order_amount,
            v_status, 'ожидает',
            v_order_notes[v_idx] || ' ' || v_order_notes[v_idx2]
        );
    END LOOP;

    -- Состав заказа, платежи, отзывы
    v_reviews_left := value * 5;
    FOR v_order_id IN SELECT order_id FROM vervykishko_food."order" LOOP
        SELECT restaurant_id, client_id, total_amount, order_timestamp
        INTO v_rest_id, v_client_id, v_total_amount, v_order_ts
        FROM vervykishko_food."order"
        WHERE order_id = v_order_id;

        SELECT ids INTO v_product_ids FROM tmp_product_ids WHERE restaurant_id = v_rest_id;

        FOR j IN 1..(1 + floor(random() * 4)::int) LOOP
            EXIT WHEN v_product_ids IS NULL OR cardinality(v_product_ids) = 0;

            v_idx := 1 + floor(random() * cardinality(v_product_ids))::int;
            v_product_id := v_product_ids[v_idx];
            v_product_ids := v_product_ids[1:v_idx - 1] || v_product_ids[v_idx + 1:cardinality(v_product_ids)];

            INSERT INTO vervykishko_food.order_structure (order_id, product_id, quantity)
            VALUES (v_order_id, v_product_id, round((1 + random() * 3)::numeric, 3))
            ON CONFLICT DO NOTHING;
        END LOOP;

        IF random() < 0.6 THEN
            v_payment_status := 'успех';
        ELSE
            v_payment_status := (enum_range(NULL::vervykishko_food.payment_status))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.payment_status)))::int];
        END IF;
        v_success := v_payment_status = 'успех';

        v_payment_type := (enum_range(NULL::vervykishko_food.payment_type))[
            1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.payment_type)))::int];

        INSERT INTO vervykishko_food.payment (
            order_id, payment_type, amount, transaction_id,
            transaction_timestamp, status
        )
        VALUES (
            v_order_id,
            v_payment_type,
            v_total_amount,
            md5(random()::text) || md5(random()::text),
            v_order_ts + (random() * 1800)::int * interval '1 second',
            v_payment_status
        );

        UPDATE vervykishko_food."order"
        SET pay_status = (CASE WHEN v_success THEN 'оплачен'
                               WHEN EXISTS (SELECT 1 FROM vervykishko_food.payment
                                            WHERE order_id = v_order_id AND status = 'ошибка')
                                    THEN 'ошибка'
                               ELSE 'ожидает' END)::vervykishko_food.order_pay_status
        WHERE order_id = v_order_id;

        IF v_reviews_left > 0 THEN
            v_review_type := (enum_range(NULL::vervykishko_food.review_entity_type))[
                1 + floor(random() * cardinality(enum_range(NULL::vervykishko_food.review_entity_type)))::int];

            IF v_review_type = 'блюдо' THEN
                SELECT product_id INTO v_product_id
                FROM vervykishko_food.order_structure
                WHERE order_id = v_order_id
                LIMIT 1;
                IF v_product_id IS NULL THEN
                    v_review_type := 'ресторан';
                END IF;
            END IF;

            v_idx := 1 + floor(random() * array_length(v_review_notes, 1))::int;
            v_idx2 := 1 + ((v_idx - 1 + 1 + floor(random() * (array_length(v_review_notes, 1) - 1))::int) % array_length(v_review_notes, 1));

            INSERT INTO vervykishko_food.review (
                client_id, review_timestamp, entity_id, entity_type,
                order_id, description, photo_url, rating
            )
            VALUES (
                v_client_id,
                v_order_ts + (60 + random() * 3600)::int * interval '1 second',
                CASE v_review_type
                    WHEN 'блюдо' THEN v_product_id
                    WHEN 'ресторан' THEN v_rest_id
                    ELSE v_order_id
                END,
                v_review_type,
                v_order_id,
                v_review_notes[v_idx] || ' ' || v_review_notes[v_idx2],
                NULL,
                round((1 + random() * 4)::numeric, 1)
            );

            v_reviews_left := v_reviews_left - 1;
        END IF;
    END LOOP;

    -- §9: выплаты за 6 месяцев через generate_series
    FOR v_month_start IN
        SELECT generate_series(
                   date_trunc('month', current_date - interval '5 months'),
                   date_trunc('month', current_date),
                   interval '1 month')::date
    LOOP
        v_month_end := (v_month_start + interval '1 month')::date;
        v_pay_year := extract(year FROM v_month_start);
        v_pay_month := extract(month FROM v_month_start);

        FOR v_courier_id IN SELECT unnest(v_couriers) LOOP
            SELECT COALESCE(SUM(commission), 0)
            INTO v_sum_commission
            FROM vervykishko_food."order"
            WHERE courier_id = v_courier_id
              AND status = 'доставлен'
              AND order_timestamp >= v_month_start
              AND order_timestamp < v_month_end;

            SELECT coefficient INTO v_coefficient
            FROM vervykishko_food.courier
            WHERE courier_id = v_courier_id;

            INSERT INTO vervykishko_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            VALUES (v_pay_year, v_pay_month, v_courier_id,
                    round(v_sum_commission * v_coefficient, 2), v_coefficient);
        END LOOP;
    END LOOP;

    -- Коэффициент на следующий месяц (BR-10.2)
    FOR v_courier_id IN SELECT unnest(v_active_couriers) LOOP
        SELECT count(*) INTO v_delivery_count
        FROM vervykishko_food."order"
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND order_timestamp >= date_trunc('month', current_date)
          AND order_timestamp < date_trunc('month', current_date) + interval '1 month';

        IF v_delivery_count <= 150 THEN v_new_coefficient := 0.10;
        ELSIF v_delivery_count <= 250 THEN v_new_coefficient := 0.20;
        ELSIF v_delivery_count <= 500 THEN v_new_coefficient := 0.30;
        ELSE v_new_coefficient := 0.50;
        END IF;

        UPDATE vervykishko_food.courier
        SET coefficient = v_new_coefficient
        WHERE courier_id = v_courier_id;
    END LOOP;

    -- §10: рейтинги генерируются напрямую, без вызова rating_change
    UPDATE vervykishko_food.product p
    SET rating = a.avg_rating
    FROM (SELECT entity_id, round(AVG(rating), 2) AS avg_rating
          FROM vervykishko_food.review
          WHERE entity_type = 'блюдо'
          GROUP BY entity_id) a
    WHERE p.product_id = a.entity_id
      AND p.rating IS DISTINCT FROM a.avg_rating;

    UPDATE vervykishko_food.restaurant r
    SET rating = a.avg_rating
    FROM (SELECT entity_id, round(AVG(rating), 2) AS avg_rating
          FROM vervykishko_food.review
          WHERE entity_type = 'ресторан'
          GROUP BY entity_id) a
    WHERE r.restaurant_id = a.entity_id
      AND r.rating IS DISTINCT FROM a.avg_rating;
END;
$$;
