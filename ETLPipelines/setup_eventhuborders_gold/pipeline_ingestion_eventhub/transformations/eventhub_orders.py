# 1. import required liberaries
from pyspark import pipelines as dp
from pyspark.sql.types import *
from pyspark.sql.functions import *

# 2. add event hub details
EH_NAMESPACE = spark.conf.get("eh.namespace")
EH_NAME = spark.conf.get("eh.name")
EH_CONN_STR = spark.conf.get("eh.connectionString")

# 3. Add Kafka Details
KAFKA_OPTIONS = {
    "kafka.bootstrap.servers": f"{EH_NAMESPACE}.servicebus.windows.net:9093",
    "subscribe": EH_NAME,
    "kafka.sasl.mechanism": "PLAIN",
    "kafka.security.protocol": "SASL_SSL",
    "kafka.sasl.jaas.config": f'kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="{EH_CONN_STR}";',
    "kafka.request.timeout.ms": "60000",
    "kafka.session.timeout.ms": "30000",
    "maxOffsetsPerTrigger": "50000",
    "failOnDataLoss": "true",
    "startingOffsets": "earliest",
}

# 4. Add Orders Structure / Schema
orders_schema = StructType([
    StructField("order_id", StringType(), True),
    StructField("timestamp", StringType(), True),
    StructField("restaurant_id", StringType(), True),
    StructField("customer_id", StringType(), True),
    StructField("order_type", StringType(), True),
    StructField("items", StringType(), True),
    StructField("total_amount", DoubleType(), True),
    StructField("payment_method", StringType(), True),
    StructField("order_status", StringType(), True)
])


# 5. Def fun
@dp.table(name="orders", table_properties={"quality": "bronze"})
def orders():
    df_raw = (
        spark.readStream
        .format("kafka")
        .options(**KAFKA_OPTIONS)
        .load()
    )

    df_parsed = (
        df_raw
        .withColumn("key_str", col("key").cast("string"))
        .withColumn("value_str", col("value").cast("string"))
        .withColumn("data", from_json("value_str", orders_schema))
        .select("data.*")
        .withColumnRenamed("timestamp", "order_timestamp")
    )
    return df_parsed