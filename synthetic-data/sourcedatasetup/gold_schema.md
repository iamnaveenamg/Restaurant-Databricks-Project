## Gold Layer Table Schemas (Databricks)

```sql
CREATE TABLE `03_gold`.d_sales_summary (
    order_date DATE PRIMARY KEY,
    total_orders BIGINT,
    total_revenue DECIMAL(12,2),
    avg_order_value DECIMAL(10,2),
    unique_customers BIGINT,
    unique_restaurants BIGINT,
    dine_in_orders BIGINT,
    takeaway_orders BIGINT,
    delivery_orders BIGINT
)

CREATE TABLE `03_gold`.d_customer_360 (
    customer_id STRING,
    customer_name STRING,
    email STRING,
    city STRING,
    loyalty_tier STRING,
    join_date DATE,
    total_orders BIGINT, 
    lifetime_spend DECIMAL(12,2),
    avg_order_value DECIMAL(10,2),
    last_order_date DATE,
    favorite_restaurant STRING,
    favorite_item STRING,
    avg_rating_given DECIMAL(3,2),
    total_reviews BIGINT,
    is_at_risk BOOLEAN,  -- No order in 90+ days
)

CREATE TABLE `03_gold`.d_restaurant_reviews (
    restaurant_id STRING PRIMARY KEY,
    restaurant_name STRING,
    city STRING,
    total_reviews BIGINT,
    avg_rating DECIMAL(3,2),
    rating_5_count BIGINT,
    rating_4_count BIGINT,
    rating_3_count BIGINT,
    rating_2_count BIGINT,
    rating_1_count BIGINT,
    sentiment_positive_count BIGINT,
    sentiment_neutral_count BIGINT,
    sentiment_negative_count BIGINT
)
```