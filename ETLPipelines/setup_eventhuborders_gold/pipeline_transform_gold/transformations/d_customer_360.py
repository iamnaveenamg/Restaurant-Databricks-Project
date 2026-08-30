from pyspark import pipelines as dp
from pyspark.sql import functions as F
from pyspark.sql.window import Window

@dp.materialized_view(
    name="03_gold.d_customer_360",
    table_properties={"quality": "gold"}
)
def d_customer_360():
    df_customers = dp.read("02_silver.dim_customers")
    df_restaurants = dp.read("02_silver.dim_restaurants")
    df_orders = dp.read("02_silver.fact_orders")
    df_order_items = dp.read("02_silver.fact_order_items")
    df_reviews = dp.read("02_silver.fact_reviews")

    df_order_stats = (
        df_orders
        .groupBy("customer_id")
        .agg(
            F.countDistinct("order_id").alias("total_orders"),
            F.sum("total_amount").alias("lifetime_spend"),
            F.round(F.avg("total_amount"), 2).alias("avg_order_value"),
            F.max("order_date").alias("last_order_date"),
        )
    )

    df_review_stats = (
        df_reviews
        .groupBy("customer_id")
        .agg(
            F.countDistinct("review_id").alias("total_reviews"),
            F.round(F.avg("rating"), 2).alias("avg_rating_given")
        )
    )

    df_fav_restaurant = (
        df_orders
        .groupBy("customer_id", "restaurant_id")
        .agg(F.countDistinct("order_id").alias("order_ct"))
        .withColumn("rn", F.row_number().over(Window.partitionBy("customer_id").orderBy(F.desc("order_ct"))))
        .filter(F.col("rn") == 1)
        .join(df_restaurants, "restaurant_id", "left")
        .select(F.col("customer_id"), F.col("name").alias("favorite_restaurant"))
    )

    df_fav_item = (
        df_orders.join(df_order_items, "order_id", "inner")
        .groupBy(df_orders.customer_id, df_order_items.item_name)
        .agg(F.sum("quantity").alias("item_qty"))
        .withColumn("rn", F.row_number().over(Window.partitionBy("customer_id").orderBy(F.desc("item_qty"))))
        .filter(F.col("rn") == 1)
        .select("customer_id", F.col("item_name").alias("favorite_item"))
    )

    df_c360 = (
        df_customers
        .join(df_order_stats, "customer_id", "left")
        .join(df_review_stats, "customer_id", "left")
        .join(df_fav_restaurant, "customer_id", "left")
        .join(df_fav_item, "customer_id", "left")    
        .select(
            F.col("customer_id"),
            F.col("name").alias("customer_name"),
            F.col("email"),
            df_customers.city,
            F.to_date(F.col("join_date")).alias("join_date"),

            # Order Stats
            F.coalesce(F.col("total_orders"), F.lit(0)).cast("bigint").alias("total_orders"),
            F.coalesce(F.col("lifetime_spend"), F.lit(0)).cast("decimal(10,2)").alias("lifetime_spend"),
            F.coalesce(F.col("avg_order_value"), F.lit(0)).cast("decimal(10,2)").alias("avg_order_value"),
            F.col("last_order_date"),
            
            # Loyalty Tier
            F.when(F.col("lifetime_spend") >= 5000, "Platinum")
            .when(F.col("lifetime_spend") >= 2000, "Gold")
            .when(F.col("lifetime_spend") >= 500, "Silver")
            .otherwise("Bronze").alias("loyalty_tier"),
            
            # Preferences
            F.col("favorite_restaurant"),
            F.col("favorite_item"),
            
            # Review Stats
            F.coalesce(F.col("avg_rating_given"), F.lit(0)).cast("decimal(10,2)").alias("avg_rating_given"),
            F.coalesce(F.col("total_reviews"), F.lit(0)).cast("bigint").alias("total_reviews"),
            
            F.when(
                F.col("lifetime_spend") >= 5000, 
                True
            ).otherwise(False).alias("is_vip")
        )
    )
    return df_c360