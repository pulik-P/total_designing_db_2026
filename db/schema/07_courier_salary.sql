CREATE OR REPLACE PROCEDURE vervykishko_food.courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    v_courier_id uuid;
    v_delivery_count int;
    v_current_coeff numeric;
    v_new_coeff numeric;
    v_sum_commission numeric;
    v_salary numeric;
    v_year int;
    v_month int;
    v_status vervykishko_food.courier_status;
BEGIN
    -- Определяем текущий год и месяц
    v_year := extract(year from current_date);
    v_month := extract(month from current_date);

    -- Проходим по каждому курьеру
    FOR v_courier_id, v_status IN (SELECT courier_id, status FROM vervykishko_food.courier) LOOP
        
        -- Считаем количество доставленных заказов за текущий месяц
        SELECT count(*) INTO v_delivery_count
        FROM vervykishko_food."order"
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND extract(year from order_timestamp) = v_year
          AND extract(month from order_timestamp) = v_month;

        -- Считаем сумму комиссий за текущий месяц
        SELECT COALESCE(SUM(commission), 0) INTO v_sum_commission
        FROM vervykishko_food."order"
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND extract(year from order_timestamp) = v_year
          AND extract(month from order_timestamp) = v_month;

        -- Получаем текущий коэффициент (который действовал в этом месяце)
        SELECT coefficient INTO v_current_coeff FROM vervykishko_food.courier WHERE courier_id = v_courier_id;

        -- Считаем зарплату
        v_salary := round(v_sum_commission * v_current_coeff, 2);

        -- Вносим запись в courier_pay (обновляем, если уже есть)
        INSERT INTO vervykishko_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, v_courier_id, v_salary, v_current_coeff)
        ON CONFLICT (year, month, courier_id) DO UPDATE
        SET amount = EXCLUDED.amount, coefficient_used = EXCLUDED.coefficient_used;

        -- Определяем новый коэффициент на следующий месяц (только для работающих)
        IF v_status != 'уволен' THEN
            IF v_delivery_count <= 150 THEN v_new_coeff := 0.1;
            ELSIF v_delivery_count <= 250 THEN v_new_coeff := 0.2;
            ELSIF v_delivery_count <= 500 THEN v_new_coeff := 0.3;
            ELSE v_new_coeff := 0.5;
            END IF;

            UPDATE vervykishko_food.courier 
            SET coefficient = v_new_coeff 
            WHERE courier_id = v_courier_id;
        END IF;
    END LOOP;
END;
$$;