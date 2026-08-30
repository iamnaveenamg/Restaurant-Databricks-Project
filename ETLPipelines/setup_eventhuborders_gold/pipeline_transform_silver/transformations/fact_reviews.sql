CREATE OR REFRESH STREAMING TABLE `02_silver`.fact_reviews (
  CONSTRAINT valid_sentiment EXPECT (sentiment IN ('positive', 'neutral', 'negative')) ON VIOLATION DROP ROW,
  CONSTRAINT non_negative_rating EXPECT (rating >= 0) ON VIOLATION DROP ROW
)
AS
SELECT 
  review_id,
  order_id,
  customer_id,
  restaurant_id,
  rating,
  review_text,
  analysis_json,
  get_json_object(analysis_json, '$.sentiment') AS sentiment,
  get_json_object(analysis_json, '$.issue_delivery') AS issue_delivery,
  get_json_object(analysis_json, '$.issue_delivery_reason') AS issue_delivery_reason,
  get_json_object(analysis_json, '$.issue_food_quality') AS issue_food_quality,
  get_json_object(analysis_json, '$.issue_food_quality_reason') AS issue_food_quality_reason,
  get_json_object(analysis_json, '$.issue_pricing') AS issue_pricing,
  get_json_object(analysis_json, '$.issue_pricing_reason') AS issue_pricing_reason,
  get_json_object(analysis_json, '$.issue_portion_size') AS issue_portion_size,
  get_json_object(analysis_json, '$.issue_portion_size_reason') AS issue_portion_size_reason,
  review_timestamp
FROM (
  SELECT
    *,
    review_text,
    ai_query(
      'databricks-meta-llama-3-1-8b-instruct',
      CONCAT(
        'Analyze the following review and return ONLY a valid JSON object with this exact structure: ',
        '{"sentiment": "<positive/neutral/negative>", ',
        '"issue_delivery": <true/false>, ',
        '"issue_delivery_reason": "<reason or empty string>", ',
        '"issue_food_quality": <true/false>, ',
        '"issue_food_quality_reason": "<reason or empty string>", ',
        '"issue_pricing": <true/false>, ',
        '"issue_pricing_reason": "<reason or empty string>", ',
        '"issue_portion_size": <true/false>, ',
        '"issue_portion_size_reason": "<reason or empty string>"}. ',
        'Rules: sentiment must be exactly one of: positive, neutral, negative. ',
        'Each issue field is true/false only. ',
        'Each reason field should contain a brief explanation if the issue is true, otherwise empty string. ',
        'Review text: ', review_text
      )
    ) AS analysis_json
  FROM STREAM(`wx_dbxproject`.`01_bronze`.reviews)
);