-- Создание расширения 
CREATE SCHEMA IF NOT EXISTS exts;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;

-- 1. Создание схемы
CREATE SCHEMA IF NOT EXISTS vervykishko_food;

-- 2. Создание ENUM-типов 
CREATE TYPE vervykishko_food.restaurant_status AS ENUM ('активен', 'неактивен');
CREATE TYPE vervykishko_food.product_status AS ENUM ('доступно', 'нет_в_наличии', 'архив');
CREATE TYPE vervykishko_food.courier_status AS ENUM ('свободен', 'занят', 'на_доставке', 'уволен');
CREATE TYPE vervykishko_food.order_status AS ENUM ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
CREATE TYPE vervykishko_food.order_pay_status AS ENUM ('ожидает', 'оплачен', 'ошибка');
CREATE TYPE vervykishko_food.payment_status AS ENUM ('успех', 'ошибка', 'в_обработке');
CREATE TYPE vervykishko_food.payment_type AS ENUM ('карта', 'наличные', 'безнал');
CREATE TYPE vervykishko_food.review_entity_type AS ENUM ('блюдо', 'ресторан', 'заказ');

-- 3. Создание таблиц и ограничений

-- Адреса
CREATE TABLE vervykishko_food.address (
    address_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street varchar(255) NOT NULL,
    house_number varchar(50) NOT NULL,
    apartment_office varchar(50) 
);

-- Клиенты
CREATE TABLE vervykishko_food.client (
    client_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login varchar(100) NOT NULL UNIQUE, 
    password varchar(32) NOT NULL,      
    phone_number varchar(20) NOT NULL UNIQUE 
);

-- Связь клиентов и адресов
CREATE TABLE vervykishko_food.client_address (
    client_id uuid NOT NULL,
    address_id uuid NOT NULL,
    PRIMARY KEY (client_id, address_id),
    FOREIGN KEY (client_id) REFERENCES vervykishko_food.client(client_id) ON DELETE CASCADE,
    FOREIGN KEY (address_id) REFERENCES vervykishko_food.address(address_id) ON DELETE CASCADE
);

-- Рестораны
CREATE TABLE vervykishko_food.restaurant (
    restaurant_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(255) NOT NULL,
    address_id uuid NOT NULL UNIQUE, 
    description text,
    work_start time NOT NULL,
    work_end time NOT NULL,
    company_details text,
    rating numeric(3, 2) CHECK (rating >= 0 AND rating <= 5), 
    status vervykishko_food.restaurant_status NOT NULL DEFAULT 'неактивен',
    FOREIGN KEY (address_id) REFERENCES vervykishko_food.address(address_id) ON DELETE RESTRICT,
    CHECK (work_end > work_start) 
);

-- Курьеры
CREATE TABLE vervykishko_food.courier (
    courier_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio varchar(255) NOT NULL,
    phone_number varchar(20) NOT NULL UNIQUE,
    status vervykishko_food.courier_status NOT NULL DEFAULT 'свободен',
    hire_date date NOT NULL,
    dismissal_date date, 
    coefficient numeric(3, 2) NOT NULL DEFAULT 0.1 CHECK (coefficient >= 0.1 AND coefficient <= 0.5), 
    CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date), 
    CHECK (
        (status = 'уволен' AND dismissal_date IS NOT NULL) OR
        (status != 'уволен' AND dismissal_date IS NULL)
    ) 
);

-- Выплаты курьерам
CREATE TABLE vervykishko_food.courier_pay (
    year int NOT NULL,
    month int NOT NULL CHECK (month >= 1 AND month <= 12),
    courier_id uuid NOT NULL,
    amount numeric(10, 2) NOT NULL CHECK (amount >= 0), 
    coefficient_used numeric(3, 2) NOT NULL CHECK (coefficient_used >= 0.1 AND coefficient_used <= 0.5), 
    PRIMARY KEY (year, month, courier_id), 
    FOREIGN KEY (courier_id) REFERENCES vervykishko_food.courier(courier_id) ON DELETE CASCADE
);

-- Категории блюд
CREATE TABLE vervykishko_food.product_category (
    product_category_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(255) NOT NULL
);

-- Блюда
CREATE TABLE vervykishko_food.product (
    product_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name varchar(255) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric(10, 2) NOT NULL CHECK (price >= 0), 
    restaurant_id uuid NOT NULL,
    photo_url text, 
    rating numeric(3, 2) CHECK (rating >= 0 AND rating <= 5),
    status vervykishko_food.product_status NOT NULL DEFAULT 'доступно',
    description text,
    FOREIGN KEY (restaurant_id) REFERENCES vervykishko_food.restaurant(restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (product_category_id) REFERENCES vervykishko_food.product_category(product_category_id) ON DELETE RESTRICT
);

-- Заказы (order - зарезервированное слово, используем кавычки)
CREATE TABLE vervykishko_food."order" (
    order_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    courier_id uuid,
    address_id uuid NOT NULL,
    order_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    delivery_timestamp timestamp,
    order_amount numeric(10, 2) NOT NULL CHECK (order_amount >= 0),
    commission numeric(10, 2) NOT NULL CHECK (commission >= 0),
    total_amount numeric(10, 2) NOT NULL CHECK (total_amount >= 1000), 
    status vervykishko_food.order_status NOT NULL DEFAULT 'создан',
    pay_status vervykishko_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description text,
    FOREIGN KEY (client_id) REFERENCES vervykishko_food.client(client_id) ON DELETE RESTRICT,
    FOREIGN KEY (restaurant_id) REFERENCES vervykishko_food.restaurant(restaurant_id) ON DELETE RESTRICT,
    FOREIGN KEY (courier_id) REFERENCES vervykishko_food.courier(courier_id) ON DELETE SET NULL,
    FOREIGN KEY (address_id) REFERENCES vervykishko_food.address(address_id) ON DELETE RESTRICT,
    CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp), 
    CHECK (round(order_amount * 0.10, 2) = commission), 
    CHECK (round(order_amount + commission, 2) = total_amount) 
);

-- Состав заказа
CREATE TABLE vervykishko_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(10, 3) NOT NULL CHECK (quantity > 0), 
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES vervykishko_food."order"(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES vervykishko_food.product(product_id) ON DELETE RESTRICT
);

-- Платежи
CREATE TABLE vervykishko_food.payment (
    payment_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id uuid NOT NULL,
    payment_type vervykishko_food.payment_type NOT NULL,
    amount numeric(10, 2) NOT NULL CHECK (amount > 0),
    transaction_id varchar(255) NOT NULL UNIQUE, 
    transaction_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    status vervykishko_food.payment_status NOT NULL,
    FOREIGN KEY (order_id) REFERENCES vervykishko_food."order"(order_id) ON DELETE CASCADE
);

-- Отзывы
CREATE TABLE vervykishko_food.review (
    review_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id uuid NOT NULL,
    review_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    entity_id uuid NOT NULL,
    entity_type vervykishko_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text,
    photo_url text, 
    rating numeric(2, 1) NOT NULL CHECK (rating >= 1 AND rating <= 5), 
    FOREIGN KEY (client_id) REFERENCES vervykishko_food.client(client_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES vervykishko_food."order"(order_id) ON DELETE CASCADE,
    UNIQUE (order_id, entity_type, entity_id)
);