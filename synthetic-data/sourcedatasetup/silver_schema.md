## Silver Layer Table Schemas (Databricks)

### Fact Tables
```sql
CREATE TABLE IF NOT EXISTS `02_silver`.fact_orders (
    order_id STRING PRIMARY KEY,
    order_timestamp TIMESTAMP,
    order_date DATE,
    order_hour INT,
    day_of_week STRING,
    is_weekend BOOLEAN,
    restaurant_id STRING,
    customer_id STRING,
    order_type STRING,
    item_count INT,
    total_amount DECIMAL(10,2),
    payment_method STRING,
    order_status STRING,
    _ingestion_timestamp TIMESTAMP
)

CREATE TABLE IF NOT EXISTS `02_silver`.fact_order_items (
    order_id STRING,
    item_id STRING,
    restaurant_id STRING,
    order_timestamp TIMESTAMP,
    order_date DATE,
    item_name STRING,
    category STRING,
    quantity INT,
    unit_price DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    _ingestion_timestamp TIMESTAMP,
    PRIMARY KEY (order_id, item_id)
)

CREATE TABLE IF NOT EXISTS `02_silver`.fact_reviews (
    review_id STRING PRIMARY KEY,
    order_id STRING,
    customer_id STRING,
    restaurant_id STRING,
    rating INT,
    review_text STRING,
    analysis_json TODO: ,
    sentiment STRING, -- positive, neutral, negative
    issue_delivery BOOLEAN,
    issue_delivery_reason STRING,
    issue_food_quality BOOLEAN,
    issue_food_quality_reason STRING,
    issue_pricing BOOLEAN,
    issue_pricing_reason STRING,
    issue_portion_size BOOLEAN,
    issue_portion_size_reason STRING,
    review_timestamp TIMESTAMP,
    _ingestion_timestamp TIMESTAMP
)
```


### Dim Tables
```sql
CREATE TABLE IF NOT EXISTS `02_silver`.dim_menu_items (
  restaurant_id STRING,
  item_id STRING,
  name STRING,
  category STRING,
  price DECIMAL(10,2),
  ingredients STRING,
  is_vegetarian BOOLEAN,
  spice_level STRING
);

CREATE TABLE IF NOT EXISTS `02_silver`.dim_restaurants (
  restaurant_id STRING,
  name STRING,
  city STRING,
  country STRING,
  address STRING,
  opening_date DATE,
  phone STRING
);

CREATE TABLE IF NOT EXISTS `02_silver`.dim_customers (
  customer_id STRING,
  name STRING,
  email STRING,
  phone STRING,
  city STRING,
  join_date STRING
);
```