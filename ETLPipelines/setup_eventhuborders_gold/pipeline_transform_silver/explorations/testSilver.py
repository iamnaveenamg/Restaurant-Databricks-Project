# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# MAGIC %md
# MAGIC     order_id STRING PRIMARY KEY,
# MAGIC     order_timestamp TIMESTAMP,
# MAGIC     order_date DATE,
# MAGIC     order_hour INT,
# MAGIC     day_of_week STRING,
# MAGIC     is_weekend BOOLEAN,
# MAGIC     restaurant_id STRING,
# MAGIC     customer_id STRING,
# MAGIC     order_type STRING,
# MAGIC     item_count INT,
# MAGIC     total_amount DECIMAL(10,2),
# MAGIC     payment_method STRING,
# MAGIC     order_status STRING,
# MAGIC     _ingestion_timestamp TIMESTAMP

# COMMAND ----------

# MAGIC %md
# MAGIC     review_id STRING PRIMARY KEY,
# MAGIC     order_id STRING,
# MAGIC     customer_id STRING,
# MAGIC     restaurant_id STRING,
# MAGIC     rating INT,
# MAGIC     review_text STRING,
# MAGIC     analysis_json TODO: ,
# MAGIC     sentiment STRING, -- positive, neutral, negative
# MAGIC     issue_delivery BOOLEAN,
# MAGIC     issue_delivery_reason STRING,
# MAGIC     issue_food_quality BOOLEAN,
# MAGIC     issue_food_quality_reason STRING,
# MAGIC     issue_pricing BOOLEAN,
# MAGIC     issue_pricing_reason STRING,
# MAGIC     issue_portion_size BOOLEAN,
# MAGIC     issue_portion_size_reason STRING,
# MAGIC     review_timestamp TIMESTAMP,
# MAGIC     _ingestion_timestamp TIMESTAMP

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT 
# MAGIC   review_id,
# MAGIC   order_id,
# MAGIC   customer_id,
# MAGIC   restaurant_id,
# MAGIC   rating,
# MAGIC   review_text,
# MAGIC   analysis_json,
# MAGIC   get_json_object(analysis_json, '$.sentiment') AS sentiment,
# MAGIC   get_json_object(analysis_json, '$.issue_delivery') AS issue_delivery,
# MAGIC   get_json_object(analysis_json, '$.issue_delivery_reason') AS issue_delivery_reason,
# MAGIC   get_json_object(analysis_json, '$.issue_food_quality') AS issue_food_quality,
# MAGIC   get_json_object(analysis_json, '$.issue_food_quality_reason') AS issue_food_quality_reason,
# MAGIC   get_json_object(analysis_json, '$.issue_pricing') AS issue_pricing,
# MAGIC   get_json_object(analysis_json, '$.issue_pricing_reason') AS issue_pricing_reason,
# MAGIC   get_json_object(analysis_json, '$.issue_portion_size') AS issue_portion_size,
# MAGIC   get_json_object(analysis_json, '$.issue_portion_size_reason') AS issue_portion_size_reason,
# MAGIC   review_timestamp
# MAGIC FROM
# MAGIC (SELECT
# MAGIC     *,
# MAGIC     review_text,
# MAGIC     ai_query(
# MAGIC       'databricks-meta-llama-3-1-8b-instruct',
# MAGIC       CONCAT(
# MAGIC         'Analyze the following review and return ONLY a valid JSON object with this exact structure: ',
# MAGIC         '{"sentiment": "<positive/neutral/negative>", ',
# MAGIC         '"issue_delivery": <true/false>, ',
# MAGIC         '"issue_delivery_reason": "<reason or empty string>", ',
# MAGIC         '"issue_food_quality": <true/false>, ',
# MAGIC         '"issue_food_quality_reason": "<reason or empty string>", ',
# MAGIC         '"issue_pricing": <true/false>, ',
# MAGIC         '"issue_pricing_reason": "<reason or empty string>", ',
# MAGIC         '"issue_portion_size": <true/false>, ',
# MAGIC         '"issue_portion_size_reason": "<reason or empty string>"}. ',
# MAGIC         'Rules: sentiment must be exactly one of: positive, neutral, negative. ',
# MAGIC         'Each issue field is true/false only. ',
# MAGIC         'Each reason field should contain a brief explanation if the issue is true, otherwise empty string. ',
# MAGIC         'Review text: ', review_text
# MAGIC       )
# MAGIC     ) AS analysis_json
# MAGIC   FROM wx_dbxproject.01_bronze.reviews
# MAGIC );