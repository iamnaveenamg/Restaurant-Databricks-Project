CREATE TABLE SCHEMA_NAME.historical_orders (
    order_id VARCHAR(256) PRIMARY KEY,
    order_timestamp DATETIME2,
    restaurant_id VARCHAR(256),
    customer_id VARCHAR(256),
    order_type VARCHAR(256),  -- dine_in, takeaway, delivery
    items VARCHAR(MAX),  -- JSON array as string
    total_amount DECIMAL,
    payment_method VARCHAR(256),
    order_status VARCHAR(256)
);

CREATE TABLE SCHEMA_NAME.reviews (
    review_id VARCHAR(256) PRIMARY KEY,
    order_id VARCHAR(256),
    customer_id VARCHAR(256),
    restaurant_id VARCHAR(256),
    review_text VARCHAR(MAX),
    rating INT,
    review_timestamp DATETIME2
);

CREATE TABLE SCHEMA_NAME.customers (
    customer_id VARCHAR(256) PRIMARY KEY,
    name VARCHAR(256),
    email VARCHAR(256),
    phone VARCHAR(256),
    city VARCHAR(256),
    join_date DATE,
);

CREATE TABLE SCHEMA_NAME.menu_items (
    restaurant_id VARCHAR(256),
    item_id VARCHAR(256),
    name VARCHAR(256),
    category VARCHAR(256),
    price DECIMAL(10,2),
    ingredients VARCHAR(256),
    is_vegetarian BIT,
    spice_level VARCHAR(256),  -- None, Mild, Medium, Hot
    PRIMARY KEY (restaurant_id, item_id)
);

CREATE TABLE SCHEMA_NAME.restaurants (
    restaurant_id VARCHAR(256) PRIMARY KEY,
    name VARCHAR(256),
    city VARCHAR(256),
    country VARCHAR(256),
    address VARCHAR(MAX),
    opening_date DATE,
    phone VARCHAR(256)
);

-- Now run projects/databricks-e2e-project/sql/utility_script.sql
-- https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/sql-server-utility

ALTER DATABASE DB_NAME SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 14 DAYS, AUTO_CLEANUP = ON);

-- Note: replace 'dbo' with the schema you're using
ALTER TABLE dbo.customers ENABLE CHANGE_TRACKING;
ALTER TABLE dbo.historical_orders ENABLE CHANGE_TRACKING;
ALTER TABLE dbo.menu_items ENABLE CHANGE_TRACKING;
ALTER TABLE dbo.restaurants ENABLE CHANGE_TRACKING;
ALTER TABLE dbo.reviews ENABLE CHANGE_TRACKING;

EXEC sys.sp_cdc_enable_db;

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'customers',
    @role_name     = NULL;
GO;

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'historical_orders',
    @role_name     = NULL;
GO;

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'menu_items',
    @role_name     = NULL;
GO;

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'restaurants',
    @role_name     = NULL;
GO;

EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'reviews',
    @role_name     = NULL;
GO;

EXEC dbo.lakeflowFixPermissions
    @User = 'databrickse2eprojUserAdmin',
    @Tables = 'ALL';

EXEC dbo.lakeflowSetupChangeTracking
    @Tables = 'ALL',
    @User = 'your_user';

-- Enable CDC on specific tables
EXEC dbo.lakeflowSetupChangeDataCapture
    @Tables = 'ALL',
    @User = 'your_password';

---------------
-- CDC Commands
---------------
update customers
set city='Abu Dhabi'
where customer_id='CUST-10000';

insert into dbo.menu_items (restaurant_id, item_id, name, category, price, ingredients, is_vegetarian, spice_level)
values ('REST-AUH-001','ITEM-999','Samosa (2 pcs)','Starter',18.49,'Potato, Peas, Spices, Pastry',1,'Medium');