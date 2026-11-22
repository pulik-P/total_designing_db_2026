-- FOOD-107. Расчёт зарплаты курьеров за текущий месяц.
-- Один проход по "order": количество доставок и сумма комиссий
-- считаются одним агрегатным запросом (без второго сканирования таблицы).
CREATE OR REPLACE PROCEDURE vervykishko_food.courier_salary()
LANGUAGE plpgsql
AS $$
DECLARE
    v_courier_id uuid;
    v_status vervykishko_food.courier_status;
    v_delivery_count int;
    v_sum_commission numeric;
    v_coefficient numeric;
    v_new_coefficient numeric;
    v_year int;
    v_month int;
BEGIN
    v_year := extract(year FROM current_date);
    v_month := extract(month FROM current_date);

    FOR v_courier_id, v_status, v_coefficient IN
        SELECT courier_id, status, coefficient
        FROM vervykishko_food.courier
    LOOP
        -- Количество доставок и сумма комиссий — один запрос
        SELECT count(*), COALESCE(SUM(commission), 0)
        INTO v_delivery_count, v_sum_commission
        FROM vervykishko_food."order"
        WHERE courier_id = v_courier_id
          AND status = 'доставлен'
          AND extract(year FROM order_timestamp) = v_year
          AND extract(month FROM order_timestamp) = v_month;

        -- Зарплата за текущий месяц по действующему коэффициенту
        INSERT INTO vervykishko_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        VALUES (v_year, v_month, v_courier_id,
                round(v_sum_commission * v_coefficient, 2), v_coefficient)
        ON CONFLICT (year, month, courier_id) DO UPDATE
        SET amount = EXCLUDED.amount,
            coefficient_used = EXCLUDED.coefficient_used;

        -- Новый коэффициент действует со следующего месяца.
        -- Уволенным коэффициент не меняем: они уже не доставляют заказы.
        IF v_status <> 'уволен' THEN
            IF v_delivery_count <= 150 THEN v_new_coefficient := 0.10;
            ELSIF v_delivery_count <= 250 THEN v_new_coefficient := 0.20;
            ELSIF v_delivery_count <= 500 THEN v_new_coefficient := 0.30;
            ELSE v_new_coefficient := 0.50;
            END IF;

            UPDATE vervykishko_food.courier
            SET coefficient = v_new_coefficient
            WHERE courier_id = v_courier_id;
        END IF;
    END LOOP;
END;
$$;
