
import asyncio
import os
import json
import time
from azure.eventhub.aio import EventHubProducerClient
from azure.eventhub import EventData
from dotenv import load_dotenv

load_dotenv()

async def trigger_alert():
    print("🚀 Triggering Alert Condition (Flooding Errors)...")
    
    # Get connection string from env or az cli (simplified for this script, assuming env is loaded or we use az cli wrapper)
    # For now, let's use the CLI to get the connection string as we did in other tests
    import sh
    az = getattr(sh, "az")
    rg = "rg-e6-dbreau"
    namespace = "eh-dbreau-allowed-grackle" # We know this from previous output, or we could fetch it dynamicallly
    
    try:
        # Get the first namespace in the resource group
        print(f"🔍 Finding namespace in {rg}...")
        namespace_list = az("eventhubs", "namespace", "list", "--resource-group", rg, "--query", "[].name", "-o", "tsv").strip()
        if not namespace_list:
            print(f"❌ No namespace found in {rg}")
            return
        namespace = namespace_list.split('\n')[0].strip() # Take the first one found
        print(f"✅ Found namespace: {namespace}")
    except Exception as e:
        print(f"❌ Error finding namespace: {e}")
        return

    print(f"🔑 Getting connection string for {namespace}...")
    try:
        conn_str_output = az("eventhubs", "namespace", "authorization-rule", "keys", "list", 
                     "--resource-group", rg, 
                     "--namespace-name", namespace, 
                     "--name", "send-policy", 
                     "--query", "primaryConnectionString", "-o", "tsv").strip()
        conn_str = conn_str_output
    except Exception as e:
         print(f"❌ Error getting connection string: {e}")
         return

    producer = EventHubProducerClient.from_connection_string(conn_str, eventhub_name="orders")
    
    async with producer:
        # Create a batch
        event_data_batch = await producer.create_batch()
        
        # Add 100 invalid events to definitely trigger the threshold > 5
        print("Sending 100 mixed malformed events to trigger 'Conversion Errors'...")
        for i in range(100):
            # 1. Non-JSON string (Conversion Error)
            event_data_batch.add(EventData(f"THIS_IS_NOT_JSON_{i}"))
            
            # 2. JSON but missing fields (Data Error if schema validation exists)
            bad_json = json.dumps({"foo": "bar", "timestamp": "invalid-date"})
            event_data_batch.add(EventData(bad_json))

        await producer.send_batch(event_data_batch)
        print("✅ Batch of 200 events sent!")

    print("⏳ Wait 5 minutes for the alert to fire in Azure Monitor...")

if __name__ == "__main__":
    asyncio.run(trigger_alert())
