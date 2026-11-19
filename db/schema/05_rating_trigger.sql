-- FOOD-105. Пересчёт агрегированного рейтинга блюда/ресторана по отзывам (BR-9.6)
-- Вспомогательная функция: пересчитывает рейтинг одной сущности.
-- Для entity_type = 'заказ' агрегата нет (BR-9.6), поэтому ничего не делает.
CREATE OR REPLACE FUNCTION vervykishko_food.recalc_rating(
    p_entity_id uuid,
    p_entity_type vervykishko_food.review_entity_type
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg numeric(3, 2);
BEGIN
    IF p_entity_type = 'блюдо' THEN
        SELECT round(AVG(rating), 2) INTO v_avg
        FROM vervykishko_food.review
        WHERE entity_type = 'блюдо' AND entity_id = p_entity_id;
        -- Если отзывов не осталось, AVG вернёт NULL — рейтинг обнуляется (BR-9.6)
        UPDATE vervykishko_food.product SET rating = v_avg WHERE product_id = p_entity_id;
    ELSIF p_entity_type = 'ресторан' THEN
        SELECT round(AVG(rating), 2) INTO v_avg
        FROM vervykishko_food.review
        WHERE entity_type = 'ресторан' AND entity_id = p_entity_id;
        UPDATE vervykishko_food.restaurant SET rating = v_avg WHERE restaurant_id = p_entity_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION vervykishko_food.rating_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM vervykishko_food.recalc_rating(OLD.entity_id, OLD.entity_type);
        RETURN OLD;
    ELSIF TG_OP = 'INSERT' THEN
        PERFORM vervykishko_food.recalc_rating(NEW.entity_id, NEW.entity_type);
        RETURN NEW;
    ELSE
        -- UPDATE: если сменилась сущность отзыва, пересчитываем и старую, и новую
        IF OLD.entity_type IS DISTINCT FROM NEW.entity_type
           OR OLD.entity_id IS DISTINCT FROM NEW.entity_id THEN
            PERFORM vervykishko_food.recalc_rating(OLD.entity_id, OLD.entity_type);
        END IF;
        PERFORM vervykishko_food.recalc_rating(NEW.entity_id, NEW.entity_type);
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trigger_rating_change ON vervykishko_food.review;
CREATE TRIGGER trigger_rating_change
AFTER INSERT OR UPDATE OR DELETE ON vervykishko_food.review
FOR EACH ROW EXECUTE FUNCTION vervykishko_food.rating_change();
