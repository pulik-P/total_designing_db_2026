# Обоснование ограничений

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `'активен'`, `'неактивен'` | BR-4.3 |
| `product_status` | `'доступно'`, `'нет_в_наличии'`, `'архив'` | BR-5.5 |
| `courier_status` | `'свободен'`, `'занят'`, `'на_доставке'`, `'уволен'` | BR-6.2 |
| `order_status` | `'создан'`, `'готовится'`, `'в_доставке'`, `'доставлен'`, `'отменён'` | BR-7.7 |
| `order_pay_status` | `'ожидает'`, `'оплачен'`, `'ошибка'` | BR-7.9 |
| `payment_status` | `'успех'`, `'ошибка'`, `'в_обработке'` | BR-8.2 |
| `payment_type` | `'карта'`, `'наличные'`, `'безнал'` | BR-8.2 |
| `review_entity_type` | `'блюдо'`, `'ресторан'`, `'заказ'` | BR-9.1 |

Все значения совпадают с BR, ничего не добавлено и не переименовано.

---

## Ловушки

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему (BR-8.2):**

`payment_type`, `amount`, `transaction_id`, `transaction_timestamp`, `status` — потому что
BR-8.2 требует у каждой попытки оплаты тип, сумму, идентификатор транзакции, дату/время и статус.

**Где хранится тип оплаты — `payment` или `order` (BR-8.6):**

В `payment`, потому что BR-8.6 говорит: тип относится к попытке, у заказа может быть
несколько попыток с разными типами (карта → наличные).

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

Составной внешний ключ `(client_id, address_id) → client_address (client_id, address_id)`.
Поля не дублируются: `client_id` и `address_id` уже есть в `order`. Такой FK не даёт
записать заказ на адрес, который не привязан к этому клиенту, — BR-7.4 обеспечивается
базой, а не приложением.

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `order.restaurant_id`:**

Проверка требует JOIN двух таблиц (`order_structure` → `product` → `order`) на каждой
вставке, поэтому вынесена в генератор тестовых данных: блюдо выбирается из массива
`product_id` того ресторана, что указан в заказе. Корректность проверяется запросом D.7
протокола (`tests.md`) — он возвращает 0. На уровне БД триггер не добавлен, чтобы не
дублировать бизнес-логику и не замедлять массовую вставку состава заказа.

### Ловушка 4: `review` — полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

Полиморфизм: `entity_id` + `entity_type`. Классический FK невозможен — одна колонка
ссылается на три разные таблицы. Валидность `entity_id` обеспечивает генератор
(для `'блюдо'` берётся блюдо из состава заказа, для `'ресторан'` — ресторан заказа,
для `'заказ'` — сам заказ) и проверяют тесты. Уникальность отзыва в рамках заказа
обеспечена `UNIQUE (order_id, entity_type, entity_id)` (BR-9.5).

---

## CHECK-ограничения

| Таблица | Столбец | Условие | BR | Обоснование |
|---|---|---|---|---|
| `address` | `street` | `btrim(street) <> ''` | BR-3.1 | адрес описывается улицей, пустой строки быть не может |
| `address` | `house_number` | `btrim(house_number) <> ''` | BR-3.1 | номер дома — обязательная часть адреса |
| `client` | `password` | `~ '^[0-9a-f]{32}$'` | BR-2.3 | пароль хранится как MD5 (32 hex-символа) |
| `restaurant` | `restaurant_name` | `btrim(...) <> ''` | BR-4.1 | у ресторана есть название |
| `restaurant` | `description` | `btrim(...) <> ''` | BR-4.1 | у ресторана есть описание |
| `restaurant` | `work_end` | `> work_start` | BR-4.4 | время закрытия позже открытия |
| `restaurant` | `rating` | `BETWEEN 0 AND 5` | BR-4.2 | диапазон рейтинга |
| `restaurant` | `inn` | `~ '^[0-9]{10}([0-9]{2})?$'` | BR-4.5 | ИНН — 10 или 12 цифр |
| `restaurant` | `ogrn` | `~ '^([0-9]{13}|[0-9]{15})$'` | BR-4.5 | ОГРН — 13 или 15 цифр |
| `restaurant` | `bank_account` | `~ '^[0-9]{20}$'` | BR-4.5 | расчётный счёт — 20 цифр |
| `courier` | `coefficient` | `BETWEEN 0.10 AND 0.50` | BR-6.4 | коэффициент от 0.1 до 0.5 включительно |
| `courier` | `dismissal_date` | `IS NULL OR >= hire_date` | BR-6.3 | дата увольнения не раньше найма |
| `courier` | `status`, `dismissal_date` | `status <> 'уволен' OR dismissal_date IS NOT NULL` | BR-6.3 | уволенный обязан иметь дату увольнения |
| `courier_pay` | `month` | `BETWEEN 1 AND 12` | BR-10.2 | выплата за конкретный месяц |
| `courier_pay` | `amount` | `>= 0 AND <= 1000000` | BR-10.4 | зарплата неотрицательна; верхняя граница отсекает ошибку расчёта |
| `courier_pay` | `coefficient_used` | `BETWEEN 0.10 AND 0.50` | BR-10.2 | применённый коэффициент из BR-6.4 |
| `product_category` | `product_category_name` | `btrim(...) <> ''` | BR-5.7 | категория — справочник с названием |
| `product` | `product_name` | `btrim(...) <> ''` | BR-5.2 | у блюда есть название |
| `product` | `description` | `btrim(...) <> ''` | BR-5.2 | у блюда есть описание |
| `product` | `price` | `>= 0 AND <= 100000` | BR-5.3 | цена неотрицательна; верхняя граница отсекает ошибку ввода |
| `product` | `rating` | `BETWEEN 0 AND 5` | BR-5.4 | диапазон рейтинга |
| `"order"` | `total_amount` | `>= 1000` | BR-7.11 | минимальная сумма заказа |
| `"order"` | `delivery_timestamp` | `IS NULL OR >= order_timestamp` | BR-7.13 | доставка не раньше создания |
| `"order"` | `status`, `delivery_timestamp` | `status <> 'доставлен' OR delivery_timestamp IS NOT NULL` | BR-7.12 | у доставленного заказа заполнено время окончания |
| `order_structure` | `quantity` | `> 0` | BR-7.15 | количество положительное |
| `payment` | `amount` | `> 0` | BR-8.4 | сумма попытки положительна |
| `payment` | `transaction_id` | `btrim(...) <> ''` | BR-8.3 | идентификатор транзакции обязателен |
| `review` | `rating` | `BETWEEN 1 AND 5` | BR-9.4 | диапазон рейтинга отзыва |

## UNIQUE-ограничения

| Таблица | Столбцы | BR | Обоснование |
|---|---|---|---|
| `client` | `login` | BR-2.2 | логин уникален |
| `client` | `phone_number` | BR-2.2 | телефон уникален |
| `courier` | `phone_number` | BR-6.1 | телефон курьера уникален |
| `restaurant` | `address_id` | BR-3.3 | у ресторана ровно один адрес; два ресторана не делят адрес |
| `restaurant` | `inn` | BR-4.5 | ИНН уникален |
| `restaurant` | `ogrn` | BR-4.5 | ОГРН уникален |
| `payment` | `transaction_id` | BR-8.3 | идентификатор транзакции уникален |
| `review` | `(order_id, entity_type, entity_id)` | BR-9.5 | не более одного отзыва на объект в заказе |

## FK-ограничения

| Таблица | Столбцы | → Таблица | BR | Обоснование |
|---|---|---|---|---|
| `client_address` | `client_id` | `client` | BR-2.4 | адрес принадлежит клиенту |
| `client_address` | `address_id` | `address` | BR-2.4 | связь с физическим адресом |
| `restaurant` | `address_id` | `address` | BR-3.3 | у ресторана один адрес |
| `courier_pay` | `courier_id` | `courier` | BR-10.3 | выплата относится к курьеру |
| `product` | `restaurant_id` | `restaurant` | BR-5.1 | блюдо принадлежит ресторану |
| `product` | `product_category_id` | `product_category` | BR-5.1 | блюдо принадлежит категории |
| `"order"` | `client_id` | `client` | BR-7.2 | заказ привязан к клиенту |
| `"order"` | `restaurant_id` | `restaurant` | BR-7.2 | заказ привязан к ресторану |
| `"order"` | `courier_id` | `courier` | BR-7.5 | доставку выполняет курьер |
| `"order"` | `address_id` | `address` | BR-7.4 | адрес доставки |
| `"order"` | `(client_id, address_id)` | `client_address` | BR-7.4 | адрес доставки принадлежит клиенту заказа |
| `order_structure` | `order_id` | `"order"` | BR-7.14 | позиция относится к заказу |
| `order_structure` | `product_id` | `product` | BR-7.14 | позиция — это блюдо |
| `payment` | `order_id` | `"order"` | BR-8.1 | платёж относится к заказу |
| `review` | `client_id` | `client` | BR-9.2 | отзыв связан с клиентом |
| `review` | `order_id` | `"order"` | BR-9.2 | отзыв связан с заказом |

Политика удаления: `CASCADE` у связей, которые не существуют без родителя
(`client_address`, `courier_pay`, `product` от ресторана, `order_structure`, `payment`,
`review`); `RESTRICT` у исторически значимых (`order` → клиент/ресторан/адрес,
`restaurant` → адрес, `product` → категория); `SET NULL` у `order.courier_id`, чтобы
удаление курьера не теряло заказ.

## NOT NULL (только бизнес-обязательные)

| Таблица | Столбец | BR | Обоснование |
|---|---|---|---|
| `client` | `password` | BR-2.1 | клиент регистрируется по паролю |
| `courier` | `last_name`, `first_name` | BR-6.1 | у курьера есть ФИО |
| `restaurant` | `description` | BR-4.1 | описание — часть карточки ресторана |
| `product` | `description` | BR-5.2 | описание — часть карточки блюда |
| `courier_pay` | `amount`, `coefficient_used` | BR-10.2 | без суммы и коэффициента выплата не имеет смысла |

Остальные `NOT NULL` очевидны из PK/FK и BR и не дублируются.

## NULL (осознанно разрешено)

| Таблица | Столбец | BR | Почему NULL |
|---|---|---|---|
| `address` | `apartment_office` | BR-3.2 | квартира/офис необязательны |
| `courier` | `middle_name` | BR-6.1 | отчества может не быть |
| `courier` | `dismissal_date` | BR-6.3 | работающий курьер не обязан иметь дату |
| `product` | `photo_url` | BR-5.6 | фотография необязательна |
| `review` | `photo_url` | BR-9.3 | фотография необязательна |
| `"order"` | `delivery_timestamp` | BR-7.12 | заполняется при статусе `'доставлен'` |
| `"order"` | `courier_id` | BR-7.5 | курьер может быть назначен позже |
| `"order"` | `description` | — | комментарий клиента необязателен |
| `product`, `restaurant` | `rating` | BR-9.6 | рейтинг появляется только после отзывов |

## DEFAULT и GENERATED

| Таблица | Столбец | Что | Обоснование |
|---|---|---|---|
| все таблицы | `*_id` | `DEFAULT exts.uuid_generate_v4()` | BR-11.1: все ID — uuid через `exts` |
| `"order"` | `order_timestamp` | `DEFAULT localtimestamp` | BR-7.1, BR-11.2 |
| `payment` | `transaction_timestamp` | `DEFAULT localtimestamp` | BR-8.2 |
| `review` | `review_timestamp` | `DEFAULT localtimestamp` | BR-9.3 |
| `"order"` | `commission` | `GENERATED ALWAYS AS (round(order_amount * 0.10, 2)) STORED` | BR-1.4, BR-7.10: комиссия — 10%, приложение не может записать несогласованное значение |
| `"order"` | `total_amount` | `GENERATED ALWAYS AS (round(order_amount + round(order_amount * 0.10, 2), 2)) STORED` | BR-7.10: итог = сумма + комиссия; вычисляет СУБД |
| `courier` | `coefficient` | `DEFAULT 0.10` | BR-6.5: начальный коэффициент нового курьера |
| `courier` | `status` | `DEFAULT 'свободен'` | BR-6.2: новый курьер свободен |

## Нормализация (3НФ)

**1НФ.** Все значения атомарны. `courier.fio` из ERD разложено на `last_name`,
`first_name`, `middle_name`; `restaurant.company_details` — на `inn`, `ogrn`,
`bank_account` (BR-4.5), потому что это разные юридические поля с разными форматами.
Повторяющихся групп нет: состав заказа вынесен в `order_structure`, адреса клиентов —
в `client_address`.

**2НФ.** Составные ключи есть в `client_address`, `order_structure`, `courier_pay`;
все неключевые атрибуты зависят от ключа целиком. Например, `quantity` в
`order_structure` зависит от пары `(order_id, product_id)`, а `amount` в `courier_pay` —
от тройки `(year, month, courier_id)`.

**3НФ.** Нет транзитивных зависимостей: неключевые атрибуты зависят только от ключа.
Особые случаи:

- `order.commission` и `order.total_amount` — вычисляемые, объявлены `GENERATED ALWAYS AS ... STORED`,
  поэтому не являются независимыми данными и не создают транзитивной зависимости
  от `order_amount`; арифметику гарантирует СУБД (BR-1.4, BR-7.10).
- `product.rating`, `restaurant.rating` — агрегаты по `review` (BR-9.6), осознанная
  денормализация для скорости чтения. Поддерживаются триггером `rating_change`;
  при отсутствии отзывов `NULL`.
- `review.entity_id` + `entity_type` — полиморфизм (BR-9.1), не нарушает 3НФ;
  валидность обеспечивает генератор и тесты (ловушка 4).
