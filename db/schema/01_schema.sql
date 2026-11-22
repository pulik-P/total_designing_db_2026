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
    street varchar(150) NOT NULL,
    house_number varchar(20) NOT NULL,
    apartment_office varchar(20),
    CONSTRAINT address_street_not_empty CHECK (btrim(street) <> ''),
    CONSTRAINT address_house_not_empty CHECK (btrim(house_number) <> '')
);

-- Клиенты
CREATE TABLE vervykishko_food.client (
    client_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login varchar(100) NOT NULL UNIQUE,
    password varchar(32) NOT NULL,
    phone_number varchar(20) NOT NULL UNIQUE,
    CONSTRAINT client_password_md5 CHECK (password ~ '^[0-9a-f]{32}$')
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
-- company_details из ERD декомпозировано до 1НФ: ИНН, ОГРН и расчётный счёт —
-- это отдельные атомарные реквизиты (BR-4.5), а не одна строка «ИНН 123...».
CREATE TABLE vervykishko_food.restaurant (
    restaurant_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(150) NOT NULL,
    address_id uuid NOT NULL UNIQUE,
    description text NOT NULL,
    work_start time NOT NULL,
    work_end time NOT NULL,
    inn varchar(12) NOT NULL UNIQUE,
    ogrn varchar(15) NOT NULL UNIQUE,
    bank_account varchar(20) NOT NULL,
    rating numeric(3, 2) CHECK (rating >= 0 AND rating <= 5),
    status vervykishko_food.restaurant_status NOT NULL DEFAULT 'неактивен',
    CONSTRAINT restaurant_name_not_empty CHECK (btrim(restaurant_name) <> ''),
    CONSTRAINT restaurant_description_not_empty CHECK (btrim(description) <> ''),
    CONSTRAINT restaurant_work_time CHECK (work_end > work_start),
    CONSTRAINT restaurant_inn_format CHECK (inn ~ '^[0-9]{10}([0-9]{2})?$'),
    CONSTRAINT restaurant_ogrn_format CHECK (ogrn ~ '^([0-9]{13}|[0-9]{15})$'),
    CONSTRAINT restaurant_bank_account_format CHECK (bank_account ~ '^[0-9]{20}$'),
    FOREIGN KEY (address_id) REFERENCES vervykishko_food.address(address_id) ON DELETE RESTRICT
);

-- Курьеры
-- ФИО из ERD декомпозировано до 1НФ: фамилия, имя и отчество — отдельные атомарные атрибуты.
CREATE TABLE vervykishko_food.courier (
    courier_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    last_name varchar(100) NOT NULL,
    first_name varchar(100) NOT NULL,
    middle_name varchar(100),
    phone_number varchar(20) NOT NULL UNIQUE,
    status vervykishko_food.courier_status NOT NULL DEFAULT 'свободен',
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric(2, 2) NOT NULL DEFAULT 0.10,    CONSTRAINT courier_coefficient_range CHECK (coefficient >= 0.10 AND coefficient <= 0.50),
    CONSTRAINT courier_dismissal_after_hire CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),
    CONSTRAINT courier_dismissed_has_date CHECK (
        status <> 'уволен' OR dismissal_date IS NOT NULL
    )
);

-- Выплаты курьерам
CREATE TABLE vervykishko_food.courier_pay (
    year int NOT NULL,
    month int NOT NULL,
    courier_id uuid NOT NULL,
    amount numeric(10, 2) NOT NULL,
    coefficient_used numeric(2, 2) NOT NULL,
    PRIMARY KEY (year, month, courier_id),
    CONSTRAINT courier_pay_month_range CHECK (month >= 1 AND month <= 12),
    CONSTRAINT courier_pay_amount_range CHECK (amount >= 0 AND amount <= 1000000),
    CONSTRAINT courier_pay_coefficient_range CHECK (coefficient_used >= 0.10 AND coefficient_used <= 0.50),
    FOREIGN KEY (courier_id) REFERENCES vervykishko_food.courier(courier_id) ON DELETE CASCADE
);

-- Категории блюд
CREATE TABLE vervykishko_food.product_category (
    product_category_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(100) NOT NULL,
    CONSTRAINT product_category_name_not_empty CHECK (btrim(product_category_name) <> '')
);

-- Блюда
CREATE TABLE vervykishko_food.product (
    product_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name varchar(150) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric(10, 2) NOT NULL,
    restaurant_id uuid NOT NULL,
    photo_url text,
    rating numeric(3, 2) CHECK (rating >= 0 AND rating <= 5),
    status vervykishko_food.product_status NOT NULL DEFAULT 'доступно',
    description text NOT NULL,
    CONSTRAINT product_name_not_empty CHECK (btrim(product_name) <> ''),
    CONSTRAINT product_description_not_empty CHECK (btrim(description) <> ''),
    CONSTRAINT product_price_range CHECK (price >= 0 AND price <= 100000),
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
    order_amount numeric(10, 2) NOT NULL,
    -- Комиссия и итог — вычисляемые атрибуты (BR-1.4, BR-7.10).
    -- Хранятся как generated always ... stored: приложение не может
    -- записать несогласованную сумму, арифметика гарантируется СУБД.
    commission numeric(10, 2) GENERATED ALWAYS AS (round(order_amount * 0.10, 2)) STORED,
    total_amount numeric(10, 2) GENERATED ALWAYS AS (round(order_amount + round(order_amount * 0.10, 2), 2)) STORED,
    status vervykishko_food.order_status NOT NULL DEFAULT 'создан',
    pay_status vervykishko_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description text,
    CONSTRAINT order_order_amount_range CHECK (order_amount >= 0),
    CONSTRAINT order_total_amount_min CHECK (total_amount >= 1000),
    -- BR-7.4: адрес доставки — один из адресов этого клиента.
    -- Составной FK на client_address не дублирует поля: client_id и address_id уже есть.
    CONSTRAINT order_address_belongs_to_client
        FOREIGN KEY (client_id, address_id)
        REFERENCES vervykishko_food.client_address (client_id, address_id) ON DELETE RESTRICT,
    CONSTRAINT order_delivery_after_order CHECK (delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp),
    CONSTRAINT order_delivered_has_timestamp CHECK (status <> 'доставлен' OR delivery_timestamp IS NOT NULL),
    FOREIGN KEY (client_id) REFERENCES vervykishko_food.client(client_id) ON DELETE RESTRICT,
    FOREIGN KEY (restaurant_id) REFERENCES vervykishko_food.restaurant(restaurant_id) ON DELETE RESTRICT,
    FOREIGN KEY (courier_id) REFERENCES vervykishko_food.courier(courier_id) ON DELETE SET NULL,
    FOREIGN KEY (address_id) REFERENCES vervykishko_food.address(address_id) ON DELETE RESTRICT
);

-- Состав заказа
CREATE TABLE vervykishko_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(10, 3) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT order_structure_quantity_positive CHECK (quantity > 0),
    FOREIGN KEY (order_id) REFERENCES vervykishko_food."order"(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES vervykishko_food.product(product_id) ON DELETE RESTRICT
);

-- Платежи
CREATE TABLE vervykishko_food.payment (
    payment_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id uuid NOT NULL,
    payment_type vervykishko_food.payment_type NOT NULL,
    amount numeric(10, 2) NOT NULL,
    transaction_id varchar(255) NOT NULL UNIQUE,
    transaction_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    status vervykishko_food.payment_status NOT NULL,
    CONSTRAINT payment_amount_positive CHECK (amount > 0),
    CONSTRAINT payment_transaction_id_not_empty CHECK (btrim(transaction_id) <> ''),
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
    rating numeric(2, 1) NOT NULL,
    CONSTRAINT review_rating_range CHECK (rating >= 1 AND rating <= 5),
    FOREIGN KEY (client_id) REFERENCES vervykishko_food.client(client_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES vervykishko_food."order"(order_id) ON DELETE CASCADE,
    UNIQUE (order_id, entity_type, entity_id)
);

-- 4. Индексы под фактические запросы приложения и отчётов.
-- PK/UNIQUE уже создают индексы; здесь — внешние ключи, по которым идут JOIN,
-- и поля, по которым фильтруют отчёты (FOOD-106, FOOD-107, FOOD-108).
CREATE INDEX idx_client_address_address ON vervykishko_food.client_address (address_id);
CREATE INDEX idx_product_restaurant ON vervykishko_food.product (restaurant_id);
CREATE INDEX idx_product_category ON vervykishko_food.product (product_category_id);
CREATE INDEX idx_order_client ON vervykishko_food."order" (client_id);
CREATE INDEX idx_order_restaurant ON vervykishko_food."order" (restaurant_id);
CREATE INDEX idx_order_courier ON vervykishko_food."order" (courier_id);
CREATE INDEX idx_order_timestamp ON vervykishko_food."order" (order_timestamp);
CREATE INDEX idx_order_structure_product ON vervykishko_food.order_structure (product_id);
CREATE INDEX idx_payment_order ON vervykishko_food.payment (order_id);
CREATE INDEX idx_review_entity ON vervykishko_food.review (entity_type, entity_id);
