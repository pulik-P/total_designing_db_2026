-- FOOD-105. Пересчёт агрегированного рейтинга блюда/ресторана по отзывам (BR-9.6, BR-9.7).
-- Одна триггерная функция: при INSERT/UPDATE/DELETE пересчитывает AVG по
-- затронутым сущностям. Для entity_type = 'заказ' агрегата нет (BR-9.6).
DROP FUNCTION IF EXISTS vervykishko_food.recalc_rating(uuid, vervykishko_food.review_entity_type);

CREATE OR REPLACE FUNCTION vervykishko_food.rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg numeric(3, 2);
BEGIN
    -- Удаление: пересчитываем рейтинг сущности из OLD
    IF TG_OP = 'DELETE' THEN
        IF OLD.entity_type = 'блюдо' THEN
            SELECT round(AVG(rating), 2) INTO v_avg
            FROM vervykishko_food.review
            WHERE entity_type = 'блюдо' AND entity_id = OLD.entity_id;
            UPDATE vervykishko_food.product SET rating = v_avg WHERE product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            SELECT round(AVG(rating), 2) INTO v_avg
            FROM vervykishko_food.review
            WHERE entity_type = 'ресторан' AND entity_id = OLD.entity_id;
            UPDATE vervykishko_food.restaurant SET rating = v_avg WHERE restaurant_id = OLD.entity_id;
        END IF;
        RETURN OLD;
    END IF;

    -- Вставка и обновление: если сущность сменилась, пересчитываем и старую
    IF TG_OP = 'UPDATE'
       AND (OLD.entity_type IS DISTINCT FROM NEW.entity_type
            OR OLD.entity_id IS DISTINCT FROM NEW.entity_id) THEN
        IF OLD.entity_type = 'блюдо' THEN
            SELECT round(AVG(rating), 2) INTO v_avg
            FROM vervykishko_food.review
            WHERE entity_type = 'блюдо' AND entity_id = OLD.entity_id;
            UPDATE vervykishko_food.product SET rating = v_avg WHERE product_id = OLD.entity_id;
        ELSIF OLD.entity_type = 'ресторан' THEN
            SELECT round(AVG(rating), 2) INTO v_avg
            FROM vervykishko_food.review
            WHERE entity_type = 'ресторан' AND entity_id = OLD.entity_id;
            UPDATE vervykishko_food.restaurant SET rating = v_avg WHERE restaurant_id = OLD.entity_id;
        END IF;
    END IF;

    IF NEW.entity_type = 'блюдо' THEN
        SELECT round(AVG(rating), 2) INTO v_avg
        FROM vervykishko_food.review
        WHERE entity_type = 'блюдо' AND entity_id = NEW.entity_id;
        UPDATE vervykishko_food.product SET rating = v_avg WHERE product_id = NEW.entity_id;
    ELSIF NEW.entity_type = 'ресторан' THEN
        SELECT round(AVG(rating), 2) INTO v_avg
        FROM vervykishko_food.review
        WHERE entity_type = 'ресторан' AND entity_id = NEW.entity_id;
        UPDATE vervykishko_food.restaurant SET rating = v_avg WHERE restaurant_id = NEW.entity_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_rating_change ON vervykishko_food.review;
CREATE TRIGGER trigger_rating_change
AFTER INSERT OR UPDATE OR DELETE ON vervykishko_food.review
FOR EACH ROW EXECUTE FUNCTION vervykishko_food.rating_change();
