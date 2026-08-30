import pandas as pd
import random
from datetime import datetime, timedelta
import json
import os

# ============================================
# LOAD MASTER DATA
# ============================================
script_dir = os.path.dirname(os.path.abspath(__file__))
df_restaurants = pd.read_csv(os.path.join(script_dir, "data", "restaurants.csv"))
df_customers = pd.read_csv(os.path.join(script_dir, "data", "customers.csv"))
df_menu_items = pd.read_csv(os.path.join(script_dir, "data", "menu_items.csv"))

RESTAURANTS = df_restaurants['restaurant_id'].tolist()
CUSTOMERS = df_customers['customer_id'].tolist()
MENU_BY_RESTAURANT = df_menu_items.groupby('restaurant_id').apply(
    lambda x: x.to_dict('records')
).to_dict()

ORDER_TYPES = ["dine_in", "takeaway", "delivery"]
PAYMENT_METHODS = ["cash", "card", "wallet"]
ORDER_STATUSES = ["delivered", "completed"]  # Only completed orders for historical data

# ============================================
# GENERATE HISTORICAL ORDER
# ============================================
def generate_historical_order(order_date):
    """Generate single historical order"""
    restaurant_id = random.choice(RESTAURANTS)
    customer_id = random.choice(CUSTOMERS)
    
    menu_items = MENU_BY_RESTAURANT[restaurant_id]
    num_items = random.randint(1, min(5, len(menu_items)))
    selected_items = random.sample(menu_items, num_items)
    
    items = []
    total_amount = 0.0
    
    for item in selected_items:
        quantity = random.randint(1, 3)
        subtotal = item["price"] * quantity
        total_amount += subtotal
        
        items.append({
            "item_id": item["item_id"],
            "name": item["name"],
            "category": item["category"],
            "quantity": quantity,
            "unit_price": item["price"],
            "subtotal": round(subtotal, 2)
        })
    
    order_id = f"ORD-{order_date.strftime('%Y%m%d')}-{random.randint(100000, 999999)}"
    
    return {
        "order_id": order_id,
        "timestamp": order_date.isoformat(),
        "restaurant_id": restaurant_id,
        "customer_id": customer_id,
        "order_type": random.choice(ORDER_TYPES),
        "items": json.dumps(items),  # Store as JSON string for CSV
        "total_amount": round(total_amount, 2),
        "payment_method": random.choice(PAYMENT_METHODS),
        "order_status": random.choice(ORDER_STATUSES),
        "created_at": order_date.isoformat()
    }

# ============================================
# GENERATE BATCH HISTORICAL ORDERS
# ============================================
def generate_historical_orders(num_orders=8000, months_back=6):
    """Generate historical orders over past X months"""
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=months_back * 30)
    
    orders = []
    
    print(f"Generating {num_orders} orders from {start_date.date()} to {end_date.date()}")
    
    for i in range(num_orders):
        # Random date within range
        days_offset = random.randint(0, (end_date - start_date).days)
        order_date = start_date + timedelta(days=days_offset)
        
        # Add random hours/minutes
        order_date = order_date.replace(
            hour=random.randint(10, 22),
            minute=random.randint(0, 59),
            second=random.randint(0, 59)
        )
        
        order = generate_historical_order(order_date)
        orders.append(order)
        
        if (i + 1) % 1000 == 0:
            print(f"Generated {i + 1} orders...")
    
    df_orders = pd.DataFrame(orders)
    
    # Sort by timestamp
    df_orders = df_orders.sort_values('timestamp').reset_index(drop=True)
    
    # Save to CSV
    df_orders.to_csv(os.path.join(script_dir, "data", "historical_orders.csv"), index=False)
    
    print(f"\nGenerated {len(df_orders)} historical orders")
    print(f"Saved to: historical_orders.csv")
    print(f"Date range: {df_orders['timestamp'].min()} to {df_orders['timestamp'].max()}")
    print(f"Total revenue: AED {df_orders['total_amount'].sum():,.2f}")

# ============================================
# MAIN
# ============================================
if __name__ == "__main__":
    generate_historical_orders(num_orders=8000, months_back=6)