/* =====================================================================
   01_schema.sql
   Creates the StoreOpt database: a small e-commerce schema.
   NOTE: only primary keys and foreign keys are defined. There are NO
   supporting indexes on purpose, so the "slow" queries are really slow.
   ===================================================================== */

IF DB_ID('StoreOpt') IS NULL
    CREATE DATABASE StoreOpt;
GO

USE StoreOpt;
GO

DROP TABLE IF EXISTS dbo.payments, dbo.order_items, dbo.orders,
                     dbo.products, dbo.categories, dbo.customers;
GO

CREATE TABLE dbo.customers (
    customer_id  INT IDENTITY(1,1) CONSTRAINT PK_customers PRIMARY KEY,
    first_name   VARCHAR(50)  NOT NULL,
    last_name    VARCHAR(50)  NOT NULL,
    email        VARCHAR(120) NOT NULL,
    city         VARCHAR(50)  NOT NULL,
    country      VARCHAR(50)  NOT NULL,
    created_at   DATETIME2    NOT NULL
);

CREATE TABLE dbo.categories (
    category_id   INT IDENTITY(1,1) CONSTRAINT PK_categories PRIMARY KEY,
    category_name VARCHAR(60) NOT NULL
);

CREATE TABLE dbo.products (
    product_id   INT IDENTITY(1,1) CONSTRAINT PK_products PRIMARY KEY,
    category_id  INT NOT NULL
        CONSTRAINT FK_products_categories REFERENCES dbo.categories(category_id),
    product_name VARCHAR(100) NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL,
    is_active    BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.orders (
    order_id     INT IDENTITY(1,1) CONSTRAINT PK_orders PRIMARY KEY,
    customer_id  INT NOT NULL
        CONSTRAINT FK_orders_customers REFERENCES dbo.customers(customer_id),
    order_date   DATETIME2 NOT NULL,
    status       VARCHAR(20) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0
);

CREATE TABLE dbo.order_items (
    order_item_id BIGINT IDENTITY(1,1) CONSTRAINT PK_order_items PRIMARY KEY,
    order_id      INT NOT NULL
        CONSTRAINT FK_items_orders REFERENCES dbo.orders(order_id),
    product_id    INT NOT NULL
        CONSTRAINT FK_items_products REFERENCES dbo.products(product_id),
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL
);

CREATE TABLE dbo.payments (
    payment_id   INT IDENTITY(1,1) CONSTRAINT PK_payments PRIMARY KEY,
    order_id     INT NOT NULL
        CONSTRAINT FK_payments_orders REFERENCES dbo.orders(order_id),
    payment_date DATETIME2 NOT NULL,
    amount       DECIMAL(12,2) NOT NULL,
    method       VARCHAR(20) NOT NULL
);
GO
