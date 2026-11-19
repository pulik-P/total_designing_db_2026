CREATE OR REPLACE PROCEDURE vervykishko_food.erase_test_data()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM vervykishko_food.review;
    DELETE FROM vervykishko_food.payment;
    DELETE FROM vervykishko_food.order_structure;
    DELETE FROM vervykishko_food.courier_pay;
    DELETE FROM vervykishko_food."order";
    DELETE FROM vervykishko_food.product;
    DELETE FROM vervykishko_food.restaurant;
    DELETE FROM vervykishko_food.client_address;
    DELETE FROM vervykishko_food.client;
    DELETE FROM vervykishko_food.courier;
    DELETE FROM vervykishko_food.product_category;
    DELETE FROM vervykishko_food.address;
END;
$$;