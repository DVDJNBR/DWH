from azure.eventhub import EventHubProducerClient, EventData
import json
import time
import random
import uuid
import os
from faker import Faker
import pyodbc

# Initialize Faker
fake = Faker()

# Environment variables
CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR")
ORDERS_INTERVAL = int(os.getenv("MARKETPLACE_ORDERS_INTERVAL", 90))

# SQL Database connection
SQL_SERVER = os.getenv("SQL_SERVER_FQDN")
SQL_DATABASE = os.getenv("SQL_DATABASE_NAME")
SQL_USER = os.getenv("SQL_ADMIN_LOGIN")
SQL_PASSWORD = os.getenv("SQL_ADMIN_PASSWORD")

if not CONNECTION_STR:
    raise RuntimeError("EVENTHUB_CONNECTION_STR not set")

if not all([SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD]):
    raise RuntimeError("SQL connection variables not set")

# Event Hub producer
producer = EventHubProducerClient.from_connection_string(
    CONNECTION_STR, 
    eventhub_name="orders"
)

# Global pools
CUSTOMERS_POOL = []
for _ in range(100):
    CUSTOMERS_POOL.append({
        "id": str(uuid.uuid4()),
        "name": fake.name(),
        "email": fake.email(),
        "address": fake.street_address(),
        "city": fake.city(),
        "country": fake.country()
    })

PRODUCTS_POOL = []
for _ in range(500):
    PRODUCTS_POOL.append({
        "product_id": str(uuid.uuid4()),
        "name": fake.catch_phrase(),
        "category": random.choice(["Electronics", "Home", "Clothing", "Books", "Beauty"]),
        "description": fake.sentence(),
        "price": round(random.uniform(5, 300), 2)
    })

def get_active_vendors():
    """Fetch active vendors from database"""
    try:
        conn_str = (
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={SQL_SERVER};"
            f"DATABASE={SQL_DATABASE};"
            f"UID={SQL_USER};"
            f"PWD={SQL_PASSWORD};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
            f"Connection Timeout=30;"
        )
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT vendor_id, vendor_name
            FROM dim_vendor
            WHERE is_current = 1
            AND vendor_status = 'active'
        """)
        
        vendors = [{"vendor_id": row.vendor_id, "vendor_name": row.vendor_name} 
                   for row in cursor.fetchall()]
        
        conn.close()
        return vendors
    except Exception as e:
        print(f"Error fetching vendors: {e}")
        return []

def build_marketplace_order(now, vendors):
    """Build order event with vendor_id"""
    if not vendors:
        print("No vendors available, skipping order generation")
        return None
    
    order_id = str(uuid.uuid4())
    items = []
    total_amount = 0
    num_items = random.randint(1, 3)
    
    # Select a random vendor for this order
    vendor = random.choice(vendors)
    
    # Select unique products
    selected_products = random.sample(PRODUCTS_POOL, num_items)
    
    for product in selected_products:
        qty = random.randint(1, 3)
        item = product.copy()
        item["quantity"] = qty
        item["unit_price"] = product["price"]  # ASA expects unit_price
        item["vendor_id"] = vendor["vendor_id"]
        items.append(item)
        total_amount += product["price"] * qty
    
    customer = random.choice(CUSTOMERS_POOL)
    
    return {
        "event_id": str(uuid.uuid4()),
        "order_id": order_id,
        "customer": customer,
        "items": items,
        "total_amount": round(total_amount, 2),
        "currency": "USD",
        "status": "PLACED",
        "timestamp": now,
        "source": "marketplace"  # Tag to identify marketplace orders
    }

def safe_send(event):
    """Send event to Event Hub"""
    try:
        batch = producer.create_batch()
        batch.add(EventData(json.dumps(event)))
        producer.send_batch(batch)
        vendor_id = event["items"][0]["vendor_id"] if event["items"] else "unknown"
        print(f"[marketplace-orders] Sent order with vendor: {vendor_id}")
    except Exception as e:
        print(f"Error sending event: {e}")

if __name__ == "__main__":
    print("🏪 Marketplace producer started")
    print(f"   Interval: {ORDERS_INTERVAL}s")
    print(f"   SQL Server: {SQL_SERVER}")
    
    # Initial vendor fetch
    vendors = get_active_vendors()
    print(f"   Found {len(vendors)} active vendors")
    
    last_vendor_refresh = time.time()
    last_order = 0.0
    
    while True:
        now = time.time()
        
        # Refresh vendors every 5 minutes
        if now - last_vendor_refresh >= 300:
            vendors = get_active_vendors()
            print(f"   Refreshed vendors: {len(vendors)} active")
            last_vendor_refresh = now
        
        # Generate marketplace order
        if now - last_order >= ORDERS_INTERVAL:
            event = build_marketplace_order(now, vendors)
            if event:
                safe_send(event)
            last_order = now
        
        time.sleep(1)
