import os
import json
import random
import time
from datetime import datetime
from azure.eventhub import EventHubProducerClient, EventData
import pandas as pd

from dotenv import load_dotenv
load_dotenv()   

EVENTHUB_CONNECTION_STRING = os.getenv("EVENTHUB_CONNECTION_STRING")
EVENTHUB_NAME = os.getenv("EVENTHUB_NAME")


# Load data
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
ORDER_STATUSES = ["pending", "confirmed", "preparing", "ready", "delivered"]

def generate_order():
    order_date = datetime.utcnow()
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
        "timestamp": order_date.isoformat() + "Z",
        "restaurant_id": restaurant_id,
        "customer_id": customer_id,
        "order_type": random.choice(ORDER_TYPES),
        "items": items,
        "total_amount": round(total_amount, 2),
        "payment_method": random.choice(PAYMENT_METHODS),
        "order_status": random.choice(ORDER_STATUSES),
        "created_at": order_date.isoformat() + "Z"
    }

def stream_to_eventhub(interval_seconds=3, max_orders=None):
    producer = EventHubProducerClient.from_connection_string(
        conn_str=EVENTHUB_CONNECTION_STRING,
        eventhub_name=EVENTHUB_NAME
    )
    
    print(f"\n\nStreaming to Event Hub: {EVENTHUB_NAME}")
    order_count = 0
    
    try:
        while True:
            order = generate_order()
            event_data_batch = producer.create_batch()
            event_data_batch.add(EventData(json.dumps(order)))
            producer.send_batch(event_data_batch)
            
            order_count += 1
            print()
            print(f"\n[{order_count}] {order['order_id']} | {order['restaurant_id']} | AED {order['total_amount']}")
            print(json.dumps(order, indent=4))
            print()
            
            if max_orders and order_count >= max_orders:
                break
            
            time.sleep(interval_seconds)
            
    except KeyboardInterrupt:
        print("\nStopped")
    finally:
        producer.close()
        pass

if __name__ == "__main__":
    stream_to_eventhub(interval_seconds=3)