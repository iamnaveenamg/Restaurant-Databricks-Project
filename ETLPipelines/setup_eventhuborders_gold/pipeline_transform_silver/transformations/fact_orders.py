# 1. Import Required Libraries
from pyspark import pipelines as dp
import pyspark.sql.functions as F
from pyspark.sql.types import *

# 2. Fact Orders Table
@dp.table(name="02_silver.fact_orders")
@dp.expect_all_or_drop(
    {
        "valid_order_id": "order_id IS NOT NULL",
        "valid_order_timestamp": "order_timestamp IS NOT NULL",
        "valid_customer_id": "customer_id IS NOT NULL",
        "valid_restaurant_id": "restaurant_id IS NOT NULL",
        "valid_item_count": "item_count > 0",
        "valid_order_status": "order_status IN ('completed', 'pending', 'ready', 'delivered', 'preparing', 'confirmed')",
        "valid_payment_method": "payment_method IN ('cash', 'card', 'wallet')",
        "valid_amount": "total_amount > 0",
    }
)
def fact_orders():
    items_schema = ArrayType(
        StructType(
            [
                StructField("item_id", StringType()),
                StructField("name", StringType()),
                StructField("category", StringType()),
                StructField("quantity", IntegerType()),
                StructField("unit_price", DecimalType(10, 2)),
                StructField("subtotal", DecimalType(10, 2)),
            ]
        )
    )

    df_fact_orders = (
        dp.read_stream("01_bronze.orders")
        .withColumn("order_timestamp", F.to_timestamp(F.col("order_timestamp")))
        .withColumn("order_date", F.to_date(F.col("order_timestamp")))
        .withColumn("order_hour", F.hour(F.col("order_timestamp")))
        .withColumn("day_of_week", F.date_format(F.col("order_timestamp"), "EEEE"))
        .withColumn(
            "is_weekend",
            F.when(
                F.date_format(F.col("order_timestamp"), "E").isin(["Sat", "Sun"]), True
            ).otherwise(False),
        )
        .withColumn("items_parsed", F.from_json(F.col("items"), items_schema))
        .withColumn("item_count", F.size(F.col("items_parsed")))
        .select(
            "order_id",
            "order_timestamp",
            "order_date",
            "order_hour",
            "day_of_week",
            "is_weekend",
            "restaurant_id",
            "customer_id",
            "order_type",
            "item_count",
            F.col("total_amount").cast("decimal(10,2)").alias("total_amount"),
            "payment_method",
            "order_status"
        )
    )
    return df_fact_orders