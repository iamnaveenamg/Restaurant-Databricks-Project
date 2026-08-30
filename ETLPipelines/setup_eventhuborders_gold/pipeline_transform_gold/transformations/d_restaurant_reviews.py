from pyspark import pipelines as dp
from pyspark.sql import functions as F
from pyspark.sql.window import Window


@dp.materialized_view(
    name="03_gold.d_restaurant_reviews",
    table_properties={"quality": "gold"}
)
def d_restaurant_reviews():
    df_restaurants = dp.read("02_silver.dim_restaurants")
    df_reviews = dp.read("02_silver.fact_reviews")

    df_review_stats = (
        df_reviews
        .groupBy("restaurant_id")
        .agg(
            # Total reviews
            F.count("review_id").alias("total_reviews"),
            
            # Average rating
            F.round(F.avg("rating"), 2).alias("avg_rating"),
            
            # Rating distribution
            F.sum(F.when(F.col("rating") == 5, 1).otherwise(0)).alias("rating_5_count"),
            F.sum(F.when(F.col("rating") == 4, 1).otherwise(0)).alias("rating_4_count"),
            F.sum(F.when(F.col("rating") == 3, 1).otherwise(0)).alias("rating_3_count"),
            F.sum(F.when(F.col("rating") == 2, 1).otherwise(0)).alias("rating_2_count"),
            F.sum(F.when(F.col("rating") == 1, 1).otherwise(0)).alias("rating_1_count"),
            
            # Sentiment counts
            F.sum(F.when(F.col("sentiment") == "positive", 1).otherwise(0)).alias("sentiment_positive_count"),
            F.sum(F.when(F.col("sentiment") == "neutral", 1).otherwise(0)).alias("sentiment_neutral_count"),
            F.sum(F.when(F.col("sentiment") == "negative", 1).otherwise(0)).alias("sentiment_negative_count"),
        )
    )

    df_restaurant_reviews = (
        df_restaurants
        .join(df_review_stats, "restaurant_id", "left")
        .select(
            F.col("restaurant_id"),
            F.col("name").alias("restaurant_name"),
            df_restaurants.city,
            
            # Review Stats
            F.coalesce(F.col("total_reviews"), F.lit(0)).cast("bigint").alias("total_reviews"),
            F.coalesce(F.col("avg_rating"), F.lit(0)).cast("decimal(10,2)").alias("avg_rating"),
            F.coalesce(F.col("rating_5_count"), F.lit(0)).cast("bigint").alias("rating_5_count"),
            F.coalesce(F.col("rating_4_count"), F.lit(0)).cast("bigint").alias("rating_4_count"),
            F.coalesce(F.col("rating_3_count"), F.lit(0)).cast("bigint").alias("rating_3_count"),
            F.coalesce(F.col("rating_2_count"), F.lit(0)).cast("bigint").alias("rating_2_count"),
            F.coalesce(F.col("rating_1_count"), F.lit(0)).cast("bigint").alias("rating_1_count"),
            
            # Sentiment Stats
            F.coalesce(F.col("sentiment_positive_count"), F.lit(0)).cast("bigint").alias("sentiment_positive_count"),
            F.coalesce(F.col("sentiment_neutral_count"), F.lit(0)).cast("bigint").alias("sentiment_neutral_count"),
            F.coalesce(F.col("sentiment_negative_count"), F.lit(0)).cast("bigint").alias("sentiment_negative_count")
        )
    )
    return df_restaurant_reviews