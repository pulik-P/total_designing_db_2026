CREATE OR REPLACE VIEW vervykishko_food.how_much_money AS
WITH RECURSIVE
-- 1. Находим первый и последний месяц с доставленными заказами
min_max_dates AS (
    SELECT 
        date_trunc('month', MIN(order_timestamp)) AS start_month,
        date_trunc('month', MAX(order_timestamp)) AS end_month
    FROM vervykishko_food."order"
    WHERE status = 'доставлен'
),
-- 2. Генерируем непрерывную серию месяцев
months AS (
    SELECT start_month AS month_start FROM min_max_dates WHERE start_month IS NOT NULL
    UNION ALL
    SELECT (month_start + interval '1 month')::date
    FROM months, min_max_dates
    WHERE month_start < end_month
),
-- 3. Считаем суммы по заказам за каждый месяц
order_stats AS (
    SELECT 
        date_trunc('month', order_timestamp)::date AS month_start,
        SUM(order_amount) AS sum_no_commission,
        SUM(total_amount) AS sum_with_commission,
        SUM(total_amount) - SUM(order_amount) AS commission
    FROM vervykishko_food."order"
    WHERE status = 'доставлен'
    GROUP BY date_trunc('month', order_timestamp)::date
),
-- 4. Считаем выплаты курьерам за каждый месяц
courier_pay_stats AS (
    SELECT 
        make_date(year, month, 1) AS month_start,
        SUM(amount) AS total_courier_pay
    FROM vervykishko_food.courier_pay
    GROUP BY year, month
),
-- 5. Собираем все вместе и считаем разницу с предыдущим месяцем
final_data AS (
    SELECT 
        m.month_start,
        COALESCE(os.sum_no_commission, 0) AS sum_no_commission,
        COALESCE(os.sum_with_commission, 0) AS sum_with_commission,
        COALESCE(os.commission, 0) AS commission,
        LAG(COALESCE(os.commission, 0)) OVER (ORDER BY m.month_start) AS prev_commission,
        COALESCE(cp.total_courier_pay, 0) AS courier_pay
    FROM months m
    LEFT JOIN order_stats os ON m.month_start = os.month_start
    LEFT JOIN courier_pay_stats cp ON m.month_start = cp.month_start
)
-- 6. Формируем итоговый результат с нужными колонками
SELECT 
    to_char(month_start, 'YYYY-MM') AS year_month,
    sum_no_commission,
    sum_with_commission,
    commission,
    prev_commission,
    (commission - prev_commission) AS commission_diff,
    courier_pay,
    (commission - courier_pay) AS net_profit
FROM final_data
ORDER BY month_start;
