import pandas as pd
import random
import requests
import os
import time
from datetime import datetime, timedelta
import json


# ============================================
# LOAD HISTORICAL ORDERS
# ============================================
script_dir = os.path.dirname(os.path.abspath(__file__))
df_orders = pd.read_csv(os.path.join(script_dir, "data", "historical_orders.csv"))

# ============================================
# REVIEW TEMPLATES
# ============================================
REVIEW_TEMPLATES = {
    5: [
        "Absolutely amazing {dishes}! The {highlight} was cooked to perfection. Fresh ingredients and authentic flavors. Highly recommend!",
        "Outstanding experience! The {dishes} exceeded all expectations. {highlight} was the star of the meal. Will definitely order again!",
        "Best Indian food in UAE! {dishes} were incredible. {highlight} had the perfect balance of spices. Five stars!",
        "Exceptional quality! Ordered {dishes} and everything was delicious. The {highlight} melted in my mouth. Perfect!",
        "Wow! Just wow! {dishes} were all fantastic. {highlight} was particularly memorable. Can't wait to order again!",
        "Hands down the best {highlight} I've ever had! {dishes} were all prepared beautifully. Fresh and flavorful!",
        "Incredible meal! {dishes} arrived hot and fresh. The {highlight} was absolutely divine. Highly satisfied!",
        "Perfect in every way! {dishes} were all excellent. {highlight} stood out with its rich, authentic taste.",
    ],
    4: [
        "Really good {dishes}! The {highlight} was delicious. Slight delay in delivery but food quality made up for it.",
        "Great food overall. {dishes} were tasty, especially the {highlight}. Would order again!",
        "Enjoyed the {dishes}! {highlight} was very good. Portion sizes were generous. Recommend!",
        "Solid experience. {dishes} were well-prepared. {highlight} had great flavor. Minor issues with packaging.",
        "Very satisfied! {dishes} were fresh and flavorful. {highlight} was the standout dish.",
        "Good quality food. {dishes} were nicely done. {highlight} could have been slightly spicier but still good!",
        "Pleasant meal! {dishes} arrived warm. {highlight} was tasty though not exceptional. Would order again.",
    ],
    3: [
        "Decent food but nothing special. {dishes} were okay. {highlight} lacked the punch I expected.",
        "Average experience. {dishes} were fine but {highlight} was a bit bland. Room for improvement.",
        "Mixed feelings. {dishes} were acceptable. {highlight} was decent but portion was small for the price.",
        "It was okay. {dishes} arrived lukewarm. {highlight} tasted fine but could be better.",
        "Not bad, not great. {dishes} were edible. {highlight} needed more seasoning.",
        "Mediocre. {dishes} were fine but forgettable. {highlight} didn't stand out.",
    ],
    2: [
        "Disappointed with {dishes}. {highlight} was cold when it arrived. Not worth the money.",
        "Below expectations. {dishes} were underwhelming. {highlight} was overcooked and dry.",
        "Not good. {dishes} arrived late and cold. {highlight} had barely any flavor. Poor quality.",
        "Unsatisfactory. {dishes} were not fresh. {highlight} tasted reheated. Won't order again.",
        "Poor experience. {dishes} were disappointing. {highlight} was burnt on the edges. Very unhappy.",
        "Expected better. {dishes} were subpar. {highlight} was too oily and greasy. Stomach upset followed.",
    ],
    1: [
        "Terrible experience! {dishes} were all inedible. {highlight} was completely burnt. Waste of money!",
        "Absolutely horrible! {dishes} arrived ice cold after 2 hour delay. {highlight} was spoiled. Disgusting!",
        "Worst food ever! {dishes} were all wrong. {highlight} made me sick. Never ordering again!",
        "Disaster! {dishes} were all stale. {highlight} had a weird smell. Completely unacceptable!",
        "Appalling quality! {dishes} were swimming in oil. {highlight} was raw inside. Health hazard!",
        "Shocking! {dishes} bore no resemblance to the menu description. {highlight} was inedible. Refund demanded!",
    ]
}


# ============================================
# HELPER FUNCTIONS
# ============================================
def extract_items_from_order(items_json):
    """Extract item names from order JSON"""
    items = json.loads(items_json)
    return [item['name'] for item in items]

def format_dishes(dishes_list):
    """Format dish names for review text"""
    if len(dishes_list) == 1:
        return dishes_list[0]
    elif len(dishes_list) == 2:
        return f"{dishes_list[0]} and {dishes_list[1]}"
    else:
        return f"{', '.join(dishes_list[:-1])}, and {dishes_list[-1]}"

def generate_review_text(rating, dishes_list):
    """Generate review text based on rating and dishes"""
    template = random.choice(REVIEW_TEMPLATES[rating])
    
    dishes_formatted = format_dishes(dishes_list)
    highlight = random.choice(dishes_list)
    
    review = template.format(
        dishes=dishes_formatted,
        highlight=highlight
    )
    
    return review.replace(',', ' ')

# ============================================
# GENERATE REVIEWS WITH IMAGES
# ============================================
def generate_customer_reviews(review_percentage=0.35):
    """Generate reviews from historical orders with images"""
    
    reviews = []
    
    # Rating distribution
    rating_weights = {
        5: 0.50,
        4: 0.25,
        3: 0.12,
        2: 0.08,
        1: 0.05
    }
    
    ratings_pool = []
    for rating, weight in rating_weights.items():
        ratings_pool.extend([rating] * int(weight * 100))
    
    print(f"\nGenerating reviews from {len(df_orders)} orders...")
    print(f"Target: {review_percentage*100}% of orders will have reviews\n")
    
    image_download_count = 0
    
    for idx, order in df_orders.iterrows():
        # Only 35% of orders get reviews
        if random.random() > review_percentage:
            continue
        
        # Extract dishes from order
        dishes = extract_items_from_order(order['items'])
        
        # Assign rating
        rating = random.choice(ratings_pool)
        
        # Generate review text
        review_text = generate_review_text(rating, dishes)
        
        # Review date: 1-7 days after order
        order_date = datetime.fromisoformat(order['timestamp'])
        review_ts = order_date + timedelta(days=random.randint(1, 7))
        
        # Generate review ID
        review_id = f"REV-{len(reviews) + 1:06d}"
        
        review = {
            "review_id": review_id,
            "order_id": order['order_id'],
            "customer_id": order['customer_id'],
            "restaurant_id": order['restaurant_id'],
            "review_text": review_text,
            "rating": rating,
            "review_timestamp": review_ts.isoformat()
        }
        
        reviews.append(review)
        
        if len(reviews) % 100 == 0:
            print(f"Generated {len(reviews)} reviews...")
    
    df_reviews = pd.DataFrame(reviews)
    df_reviews = df_reviews.sort_values('review_timestamp').reset_index(drop=True)
    df_reviews.to_csv(os.path.join(script_dir, "data", "customer_reviews.csv"), index=False)
    
    # Statistics
    print(f"\n" + "="*60)
    print(f"GENERATION COMPLETE")
    print("="*60)
    print(f"Total reviews: {len(df_reviews)}")
    print(f"Saved to: customer_reviews.csv")
    print(f"\nRating Distribution:")
    print(df_reviews['rating'].value_counts().sort_index())
    print(f"Date range: {df_reviews['review_timestamp'].min()} to {df_reviews['review_timestamp'].max()}")

# ============================================
# MAIN
# ============================================
if __name__ == "__main__":
    generate_customer_reviews(review_percentage=0.01)