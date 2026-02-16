import os
import json
import time
from azure.eventhub import EventHubProducerClient, EventData
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

CONNECTION_STR = os.getenv("EVENTHUB_CONNECTION_STR")
EVENTHUB_NAME = "orders"

if not CONNECTION_STR:
    print("❌ Error: EVENTHUB_CONNECTION_STR not found in .env")
    exit(1)

def send_malformed_events(count=10):
    print(f"🚀 Starting Alert Stress Test: Sending {count} malformed events...")
    producer = EventHubProducerClient.from_connection_string(
        conn_str=CONNECTION_STR, 
        eventhub_name=EVENTHUB_NAME
    )
    
    with producer:
        batch = producer.create_batch()
        for i in range(count):
            # MALFORMED EVENT: Massive payload or invalid structure
            # To trigger an error in ASA/SQL, we send a null order_id 
            # while the quarantine is DISABLED.
            event_data = {
                "order_id": None, # Should be NOT NULL in SQL
                "customer": {"id": "CUST-999", "name": "Alert Tester"},
                "items": [{"product_id": "P-001", "quantity": 1, "unit_price": 10.0}],
                "timestamp": time.time(),
                "test_marker": f"ALERT_STRESS_TEST_{int(time.time())}_{i}"
            }
            batch.add(EventData(json.dumps(event_data)))
            print(f"  [#{i+1}] Added null order_id event")
            
        producer.send_batch(batch)
    
    print(f"✅ Sent {count} malformed events to '{EVENTHUB_NAME}'.")
    print("⏳ Now wait 2-5 minutes for Azure to process and trigger the alert.")

if __name__ == "__main__":
    send_malformed_events(10)
