# Обоснование ограничений

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| restaurant_status | 'активен', 'неактивен' | BR-4.3 |
| product_status | 'доступно', 'нет_в_наличии', 'архив' | BR-5.5 |
| courier_status | 'свободен', 'занят', 'на_доставке', 'уволен' | BR-6.2 |
| order_status | 'создан', 'готовится', 'в_доставке', 'доставлен', 'отменён' | BR-7.7 |
| order_pay_status | 'ожидает', 'оплачен', 'ошибка' | BR-7.9 |
| payment_status | 'успех', 'ошибка', 'в_обработке' | BR-8.2 |
| payment_type | 'карта', 'наличные', 'безнал' | BR-8.2 |
| review_entity_type | 'блюдо', 'ресторан', 'заказ' | BR-9.1 |

## Особые случаи реализации

### 1. Сущность payment и её атрибуты
**Обоснование:** В ERD указана сущность `payment`, но BR-8.2 требует хранить тип оплаты, сумму, ID транзакции, время и статус.
**Реализация:** В таблицу `payment` добавлены атрибуты `payment_type`, `amount`, `transaction_id`, `transaction_timestamp`, `status`. 
Тип оплаты (`payment_type`) хранится в `payment`, а не в `order`, так как BR-8.6 гласит: «Тип оплаты относится к попытке оплаты, а не к заказу». Атрибут `transaction_id` объявлен с ограничением `UNIQUE`, так как BR-8.3 требует уникальности внешнего идентификатора. Сумма попытки равна общей сумме заказа (BR-8.4) — это проверяется на уровне приложения/тестов.

### 2. Принадлежность адреса доставки клиенту (BR-7.4)
**Обоснование:** По BR-7.4 адрес доставки должен принадлежать клиенту, оформляющему заказ. Простой FK на таблицу `address` этого не гарантирует.
**Реализация:** Обеспечено на уровне приложения. В БД невозможно поставить простой FK на составную таблицу `client_address` без дублирования полей в `order` (что нарушило бы нормализацию). Валидность связи проверяется в тестах (пункт D.6 протокола).

### 3. Блюда в заказе из одного ресторана (BR-7.3)
**Обоснование:** Все блюда в заказе должны быть из одного ресторана (того, что указан в `order.restaurant_id`).
**Реализация:** На уровне БД это можно реализовать через триггер, проверяющий `product.restaurant_id` при вставке в `order_structure`. В данной работе для сохранения простоты схемы проверка вынесена в тесты (пункт D.7 протокола). Генератор тестовых данных (`insert_test_data`) гарантирует, что все блюда в заказе берутся из одного ресторана.

### 4. Полиморфизм отзывов (BR-9.1)
**Обоснование:** Отзыв может ссылаться на блюдо, ресторан или заказ (BR-9.1). Классический FK здесь невозможен.
**Реализация:** Использован полиморфный подход: поля `entity_id` (uuid) и `entity_type` (enum). Валидность `entity_id` (существование сущности) не проверяется на уровне БД, так как это потребовало бы динамического FK. Проверка существования сущности выполняется на уровне приложения. Уникальность отзыва в рамках заказа обеспечивается ограничением `UNIQUE (order_id, entity_type, entity_id)` (BR-9.5).

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| restaurant | rating | BETWEEN 0 AND 5 | BR-4.2 | Рейтинг от 0 до 5 |
| restaurant | work_end | > work_start | BR-4.4 | Время закрытия позже открытия |
| courier | coefficient | BETWEEN 0.1 AND 0.5 | BR-6.4 | Коэффициент от 0.1 до 0.5 |
| courier | dismissal_date | >= hire_date | BR-6.3 | Дата увольнения не раньше найма |
| courier | status, dismissal_date | (status='уволен' AND dismissal_date IS NOT NULL) OR (status!='уволен' AND dismissal_date IS NULL) | BR-6.3 | Уволенный обязан иметь дату, работающий - нет |
| courier_pay | amount | >= 0 | BR-10.4 | Сумма зарплаты неотрицательна |
| courier_pay | coefficient_used | BETWEEN 0.1 AND 0.5 | BR-6.4 | Коэффициент от 0.1 до 0.5 |
| product | price | >= 0 | BR-5.3 | Цена неотрицательна |
| product | rating | BETWEEN 0 AND 5 | BR-5.4 | Рейтинг от 0 до 5 |
| "order" | total_amount | >= 1000 | BR-1.8, BR-7.11 | Минимальная сумма заказа |
| "order" | delivery_timestamp | IS NULL OR >= order_timestamp | BR-7.13 | Время окончания доставки не раньше создания |
| "order" | commission | round(order_amount * 0.10, 2) = commission | BR-1.4, BR-7.10 | Комиссия 10% |
| "order" | total_amount | round(order_amount + commission, 2) = total_amount | BR-7.10 | Общая сумма = сумма + комиссия |
| order_structure | quantity | > 0 | BR-7.15 | Количество положительное |
| payment | amount | > 0 | BR-8.4 | Сумма попытки положительна |
| review | rating | BETWEEN 1 AND 5 | BR-9.4 | Рейтинг отзыва от 1 до 5 |

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| client | login | BR-2.2 | Логин уникален |
| client | phone_number | BR-2.2 | Телефон уникален |
| courier | phone_number | BR-6.1 | Телефон курьера уникален (следует из бизнес-логики) |
| restaurant | address_id | BR-3.3 | Два ресторана не могут делить адрес |
| payment | transaction_id | BR-8.3 | ID транзакции уникален |
| review | (order_id, entity_type, entity_id) | BR-9.5 | Не более одного отзыва на объект в заказе |

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| client_address | client_id | client | BR-2.4 | Связь клиента и адреса |
| client_address | address_id | address | BR-2.4 | Связь клиента и адреса |
| restaurant | address_id | address | BR-3.3 | У ресторана ровно один адрес |
| courier_pay | courier_id | courier | BR-10.3 | Выплата относится к курьеру |
| product | restaurant_id | restaurant | BR-5.1 | Блюдо принадлежит ресторану |
| product | product_category_id | product_category | BR-5.1 | Блюдо принадлежит категории |
| "order" | client_id | client | BR-7.2 | Заказ привязан к клиенту |
| "order" | restaurant_id | restaurant | BR-7.2 | Заказ привязан к ресторану |
| "order" | courier_id | courier | BR-7.5 | Доставку выполняет курьер |
| "order" | address_id | address | BR-7.4 | Адрес доставки |
| order_structure | order_id | "order" | BR-7.14 | Позиция относится к заказу |
| order_structure | product_id | product | BR-7.14 | Позиция — это блюдо |
| payment | order_id | "order" | BR-8.1 | Платеж относится к заказу |
| review | client_id | client | BR-9.2 | Отзыв связан с клиентом |
| review | order_id | "order" | BR-9.2 | Отзыв связан с заказом |

## NOT NULL (только бизнес-обязательные)
| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| client | password | BR-2.1 | Клиент регистрируется по паролю |
| courier | fio | BR-6.1 | У курьера есть ФИО |

## NULL (осознанно разрешено)
| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| address | apartment_office | BR-3.2 | Квартира/офис необязательна |
| courier | dismissal_date | BR-6.3 | У работающего курьера даты увольнения нет |
| product | photo_url | BR-5.6 | Фотография необязательна |
| review | photo_url | BR-9.3 | Фотография необязательна |
| "order" | delivery_timestamp | BR-7.12 | Заполняется при статусе 'доставлен' |
| "order" | courier_id | - | Заказ может быть создан до назначения курьера |

## 5. Пересчёт рейтингов (FOOD-105, BR-9.6)

`product.rating` и `restaurant.rating` — агрегаты по `review.rating`, хранятся денормализованно ради скорости чтения и поддерживаются триггером `rating_change` (`AFTER INSERT OR UPDATE OR DELETE` на `review`):

* при вставке и удалении отзыва пересчитывается рейтинг сущности `NEW`/`OLD`;
* при обновлении, если изменились `entity_type` или `entity_id`, пересчитываются обе сущности — старая и новая;
* `entity_type = 'заказ'` не пересчитывается: у заказа агрегата нет (BR-9.6);
* если отзывов на сущность не осталось, `AVG()` возвращает `NULL`, и рейтинг становится `NULL`;
* рекурсии нет: триггер изменяет только `product` и `restaurant`, отзывы не затрагивает.

Пересчёт вынесен во вспомогательную функцию `recalc_rating(uuid, review_entity_type)`, чтобы не дублировать код для `OLD` и `NEW`; сама бизнес-логика FOOD-105 находится в `rating_change()`.

Генератор `insert_test_data` создаёт блюда и рестораны с `rating = NULL` — начальные значения не выдумываются, рейтинг появляется только из реальных отзывов.

## 6. Выплаты курьерам (FOOD-107, BR-10.2–BR-10.4)

Первичный ключ `courier_pay` — составной `(year, month, courier_id)`, без суррогатного `uuid`: BR-10.3 требует ровно одну запись на курьера в месяц, и этот ключ одновременно обеспечивает ограничение и позволяет `courier_salary()` делать `INSERT ... ON CONFLICT DO UPDATE` без дубликатов.

`courier.coefficient` — коэффициент, действующий со следующего месяца: `courier_salary()` сначала считает зарплату за текущий месяц по текущему коэффициенту и пишет её в `courier_pay.coefficient_used`, затем обновляет `coefficient` по числу доставок (у уволенных коэффициент не меняется).

## 7. Резервная копия и схема `exts` (FOOD-110, BR-13.3)

Дамп `db/foodexpress_vervykishko.backup` (`pg_dump -Fc --no-owner --no-privileges --schema=vervykishko_food`) содержит **только** схему `vervykishko_food` — это прямо требуется в FOOD-110. Схема `exts` с `uuid-ossp` в дамп не входит: по BR-13.3 она уже создана в базе и не пересоздаётся.

Поэтому восстановление выполняется в подготовленную БД:

```bash
createdb foodexpress_check
psql -d foodexpress_check -c 'CREATE SCHEMA IF NOT EXISTS exts; CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;'
pg_restore -d foodexpress_check db/foodexpress_vervykishko.backup
psql -d foodexpress_check -f db/schema/grants.sql
```

`--no-owner --no-privileges` убирают из дампа зависимость от имён ролей: объекты принадлежат тому, кто восстанавливает, а права `inspector` выдаёт `grants.sql` (FOOD-109). Проверка восстановления и работы под `inspector` — в `tests.md`, пункты A.1 и G.5.

## Нормализация (3НФ)
Все таблицы находятся в 3НФ. Нет транзитивных зависимостей. Атрибуты `order.commission` и `order.total_amount` являются вычисляемыми, но хранятся для соответствия требованиям и для упрощения запросов (осознанная денормализация). Рейтинги `product.rating` и `restaurant.rating` также являются агрегатами и поддерживаются триггером (FOOD-105) — это осознанная денормализация для скорости чтения.