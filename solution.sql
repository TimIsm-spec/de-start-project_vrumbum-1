-- Этап 1. Создание и заполнение БД
-- Этап 1. Создание и заполнение БД

--Создаем схему

CREATE SCHEMA car_shop;



--Создаем таблицу стран

CREATE TABLE car_shop.countries (    

country_id SERIAL PRIMARY KEY,  

  name VARCHAR(50) NOT NULL UNIQUE

);



--Создаем таблицу цветов

CREATE TABLE car_shop.colors (   

 color_id SERIAL PRIMARY KEY,   

 name VARCHAR(30) NOT NULL UNIQUE

);



--Таблица брендов автомобилей (с привязкой к стране)

CREATE TABLE car_shop.brands (   

 brand_id SERIAL PRIMARY KEY,    

brand_name VARCHAR(50) NOT NULL UNIQUE,  

 country_id INTEGER REFERENCES car_shop.countries(country_id) 

);



--Таблица моделей автомобилей (с привязкой к бренду)

CREATE TABLE car_shop.models (    

      model_id SERIAL PRIMARY KEY,   

      brand_id INTEGER REFERENCES car_shop.brands(brand_id),    

     model_name VARCHAR(50) NOT NULL,

     gasoline_consumption NUMERIC(4,1)  CHECK (gasoline_consumption > 0),

     UNIQUE(brand_id, model_name) 

);





--Создаем таблицу клиентов

CREATE TABLE car_shop.customers (  

   customer_id SERIAL PRIMARY KEY,   

   full_name VARCHAR(100) NOT NULL,

   phone VARCHAR(50));



-- Таблица автомобилей (объединяет модель и цвет)

CREATE TABLE car_shop.cars (  

     car_id SERIAL PRIMARY KEY,

    model_id INTEGER NOT NULL REFERENCES car_shop.models(model_id),   

     color_id INTEGER NOT NULL REFERENCES car_shop.colors(color_id) );





-- Основная таблица продаж (соответствует исходным данным)

CREATE TABLE car_shop.sales (   

   sale_id SERIAL PRIMARY KEY,  

  car_id INTEGER NOT NULL REFERENCES car_shop.cars(car_id),  

  customer_id INTEGER NOT NULL REFERENCES car_shop.customers(customer_id),

  price NUMERIC(10,2) NOT NULL CHECK (price > 0),   

  sale_date DATE NOT NULL,  

  discount INTEGER NOT NULL CHECK (discount BETWEEN 0 AND 100) );





-- Заполняем страны

INSERT INTO car_shop.countries (name)

SELECT DISTINCT brand_origin 

FROM raw_data.sales;



-- Заполняем цвета

INSERT INTO car_shop.colors (name)

SELECT DISTINCT split_part(auto, ', ', 2) 

FROM raw_data.sales;



-- Заполняем бренды

INSERT INTO car_shop.brands (brand_name, country_id)

SELECT DISTINCT  

        SPLIT_PART(auto, ' ', 1) as brand_name,  

        c.country_id

FROM raw_data.sales s

JOIN car_shop.countries c ON s.brand_origin = c.name;





-- Заполняем модели

INSERT INTO car_shop.models (brand_id, model_name, gasoline_consumption)

SELECT DISTINCT ON (b.brand_id, model_name)

   b.brand_id,  

   TRIM(

       CONCAT(

           SPLIT_PART(SPLIT_PART(s.auto, ',', 1), ' ', 2),

           ' ',

           SPLIT_PART(SPLIT_PART(s.auto, ',', 1), ' ', 3)

       )

   ) AS model_name,  

   CASE

      WHEN s.gasoline_consumption = 'null' THEN NULL

      ELSE CAST(s.gasoline_consumption AS NUMERIC(4,1))

   END AS gasoline_consumption

FROM raw_data.sales s

JOIN car_shop.brands b

  ON SPLIT_PART(auto, ' ', 1) = b.brand_name

WHERE s.gasoline_consumption IS NOT NULL

ON CONFLICT (brand_id, model_name) DO NOTHING



-- Заполняем cars

INSERT INTO car_shop.cars (model_id, color_id)

SELECT

 m.model_id,

 c.color_id

FROM raw_data.sales s

JOIN car_shop.brands b ON

 TRIM(SPLIT_PART(s.auto, ' ', 1)) = b.brand_name

JOIN car_shop.models m ON

 m.brand_id = b.brand_id AND

 m.model_name = TRIM(

   CONCAT(

     SPLIT_PART(SPLIT_PART(s.auto, ',', 1), ' ', 2),

     ' ',

     SPLIT_PART(SPLIT_PART(s.auto, ',', 1), ' ', 3)

   )

 )

JOIN car_shop.colors c ON

 TRIM(SPLIT_PART(s.auto, ',', 2)) = c.name;





--Заполнение таблицы customers

INSERT INTO car_shop.customers (full_name, phone)

SELECT

  person_name,

  phone

FROM raw_data.sales;



Заполнение таблицы sales

INSERT INTO car_shop.sales (car_id, customer_id, price, sale_date, discount)

SELECT

  c.car_id,

  cust.customer_id,

  s.price,

  s.date::date,

  s.discount

FROM raw_data.sales s

JOIN car_shop.customers cust

  ON s.person_name = cust.full_name AND s.phone = cust.phone

JOIN car_shop.cars c

  ON c.car_id = s.id;



-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT

  COUNT(*) AS total,

  ROUND(

    SUM(CASE WHEN gasoline_consumption IS NULL THEN 1 ELSE 0 END) * 100.0 /

    COUNT(*),    2  ) AS nulls_percentage_gasoline_consumption

FROM car_shop.models;




---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT

      b.brand_name,

      EXTRACT(YEAR FROM s.sale_date) AS year,

      ROUND(AVG(s.price * (1 - s.discount/100)), 2) AS price_avg

FROM car_shop.sales s

JOIN car_shop.cars c USING (car_id)

JOIN car_shop.models m USING (model_id)

JOIN car_shop.brands b USING (brand_id)

GROUP BY

      b.brand_name,

     EXTRACT(YEAR FROM s.sale_date)

ORDER BY

    b.brand_name ASC,

    year ASC;

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT

    EXTRACT(MONTH FROM s.sale_date) AS month,  -- Получаем номер месяца (1-12)

    2022 AS year,                              -- Явно указываем год

    ROUND(AVG(s.price * (1 - s.discount/100.0)), 2) AS price_avg  -- Средняя цена со скидкой

FROM

    car_shop.sales s

WHERE

    EXTRACT(YEAR FROM s.sale_date) = 2022      -- Только 2022 год

GROUP BY

    EXTRACT(MONTH FROM s.sale_date)            -- Группируем по месяцам

ORDER BY

    month;

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT

    c.full_name AS person,

    STRING_AGG(b.brand_name || ' ' || m.model_name, ', ') AS cars

FROM

    car_shop.customers c

JOIN    car_shop.sales s USING (customer_id)

JOIN    car_shop.cars ca USING (car_id)

JOIN    car_shop.models m USING (model_id)

JOIN    car_shop.brands b USING (brand_id)

GROUP BY

    c.full_name

ORDER BY

    person;

---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.

SELECT

COUNT(*) AS persons_from_usa_count

FROM

car_shop.customers

WHERE

phone LIKE '+1%';


