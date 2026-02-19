#!/usr/bin/env python3
"""
Test Quarantine
===============

Test that invalid events are routed to quarantine storage instead of the database.

Usage:
    uv run --directory scripts python tests/test_quarantine.py
"""

import json
import sys
import time
import uuid
from pathlib import Path

import sh
from azure.eventhub import EventData, EventHubProducerClient
from azure.storage.blob import BlobServiceClient
from dotenv import load_dotenv

# Load environment
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

# Colors
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
RED = '\033[0;31m'
CYAN = '\033[0;36m'
NC = '\033[0m'


def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent.parent / "terraform"
    terraform = getattr(sh, "terraform")
    result = terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
    return result.strip()


def get_eventhub_connection():
    """Get Event Hub connection string"""
    namespace = get_terraform_output("eventhub_namespace")
    rg = get_terraform_output("resource_group_name")

    az = getattr(sh, "az")
    connection_string = az(
        "eventhubs", "namespace", "authorization-rule", "keys", "list",
        "--namespace-name", namespace,
        "--name", "send-policy",
        "--resource-group", rg,
        "--query", "primaryConnectionString",
        "-o", "tsv"
    ).strip()
    return connection_string


def get_storage_connection():
    """Get quarantine storage connection string"""
    storage_account = get_terraform_output("quarantine_storage_account_name")
    if not storage_account:
        return None

    rg = get_terraform_output("resource_group_name")

    az = getattr(sh, "az")
    connection_string = az(
        "storage", "account", "show-connection-string",
        "--name", storage_account,
        "--resource-group", rg,
        "--query", "connectionString",
        "-o", "tsv"
    ).strip()
    return connection_string


def send_invalid_order():
    """Send an invalid order event (missing order_id)"""
    print(f"{CYAN}📤 Sending invalid order (null order_id)...{NC}")

    connection_string = get_eventhub_connection()

    # Invalid order: missing order_id
    invalid_order = {
        "order_id": None,  # Invalid!
        "customer": {
            "id": str(uuid.uuid4()),
            "name": "Test Customer",
            "email": "test@test.com",
            "address": "123 Test St",
            "city": "Test City",
            "country": "Test Country"
        },
        "items": [
            {
                "product_id": str(uuid.uuid4()),
                "name": "Test Product",
                "category": "Test",
                "quantity": 1,
                "unit_price": 10.00,
                "vendor_id": "SHOPNOW"
            }
        ],
        "total_amount": 10.00,
        "status": "PLACED",
        "timestamp": int(time.time()),
        "test_marker": f"QUARANTINE_TEST_{int(time.time())}"
    }

    producer = EventHubProducerClient.from_connection_string(
        connection_string,
        eventhub_name="orders"
    )

    with producer:
        batch = producer.create_batch()
        batch.add(EventData(json.dumps(invalid_order)))
        producer.send_batch(batch)

    print(f"  Test marker: {invalid_order['test_marker']}")
    print(f"{GREEN}✓ Invalid order sent{NC}")
    return invalid_order


def send_invalid_clickstream():
    """Send an invalid clickstream event (missing session_id)"""
    print(f"{CYAN}📤 Sending invalid clickstream (null session_id)...{NC}")

    connection_string = get_eventhub_connection()

    # Invalid clickstream: missing session_id
    invalid_event = {
        "event_id": str(uuid.uuid4()),
        "session_id": None,  # Invalid!
        "user_id": None,     # Invalid!
        "url": "https://test.com/page",
        "event_type": "page_view",
        "timestamp": int(time.time()),
        "test_marker": f"QUARANTINE_TEST_{int(time.time())}"
    }

    producer = EventHubProducerClient.from_connection_string(
        connection_string,
        eventhub_name="clickstream"
    )

    with producer:
        batch = producer.create_batch()
        batch.add(EventData(json.dumps(invalid_event)))
        producer.send_batch(batch)

    print(f"  Test marker: {invalid_event['test_marker']}")
    print(f"{GREEN}✓ Invalid clickstream sent{NC}")
    return invalid_event


def check_quarantine_storage(container_name, test_marker, max_wait=90):
    """Check if invalid event arrived in quarantine storage"""
    print(f"{CYAN}🔍 Checking quarantine storage ({container_name})...{NC}")
    print(f"{CYAN}⏳ Waiting for Stream Analytics to process (max {max_wait}s)...{NC}")

    storage_conn = get_storage_connection()
    if not storage_conn:
        print(f"{YELLOW}⚠ Quarantine storage not configured (enable_quarantine=false?){NC}")
        return None

    blob_service = BlobServiceClient.from_connection_string(storage_conn)
    container_client = blob_service.get_container_client(container_name)

    start_time = time.time()
    while time.time() - start_time < max_wait:
        # List recent blobs
        blobs = list(container_client.list_blobs())

        # Check newest blobs for our test marker
        for blob in sorted(blobs, key=lambda b: b.last_modified, reverse=True)[:10]:
            blob_client = container_client.get_blob_client(blob.name)
            content = blob_client.download_blob().readall().decode('utf-8')

            # Check each line (JSON Lines format)
            for line in content.strip().split('\n'):
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    if data.get('test_marker') == test_marker:
                        elapsed = int(time.time() - start_time)
                        print(f"{GREEN}✓ Found in quarantine after {elapsed}s{NC}")
                        print(f"  Blob: {blob.name}")
                        return data
                except json.JSONDecodeError:
                    continue

        print(".", end="", flush=True)
        time.sleep(5)

    print(f"\n{RED}✗ Not found in quarantine after {max_wait}s{NC}")
    return None



class OutputBuffer:
    """Buffer to capture stdout and write to file"""
    def __init__(self, filename):
        self.filename = filename
        self.buffer = []
        self.original_stdout = sys.stdout

    def write(self, text):
        self.buffer.append(text)
        self.original_stdout.write(text)

    def flush(self):
        self.original_stdout.flush()

    def save(self):
        with open(self.filename, 'w') as f:
            # Remove color codes
            text = ''.join(self.buffer)
            for color in [GREEN, YELLOW, RED, CYAN, NC]:
                text = text.replace(color, '')
            f.write(text)


def main():
    """Main test function"""
    report_path = Path(__file__).parent / 'quarantine_report.txt'
    output_buffer = OutputBuffer(str(report_path))
    sys.stdout = output_buffer
    
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test: Data Quality Quarantine{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    try:
        # Check if quarantine is enabled
        storage_account = get_terraform_output("quarantine_storage_account_name")
        if not storage_account:
            print(f"{RED}✗ Quarantine not enabled{NC}")
            print(f"{YELLOW}💡 Deploy with enable_quarantine=true{NC}")
            sys.exit(1)

        print(f"{GREEN}✓ Quarantine storage: {storage_account}{NC}\n")

        tests_passed = 0
        tests_failed = 0

        # Test 1: Invalid order
        print(f"\n{CYAN}--- Test 1: Invalid Order (null order_id) ---{NC}")
        invalid_order = send_invalid_order()
        container_orders = get_terraform_output("quarantine_container_orders")

        result = check_quarantine_storage(container_orders, invalid_order['test_marker'])
        if result:
            tests_passed += 1
            print(f"{GREEN}✓ Invalid order correctly quarantined{NC}")
        else:
            tests_failed += 1
            print(f"{RED}✗ Invalid order not found in quarantine{NC}")

        # Test 2: Invalid clickstream
        print(f"\n{CYAN}--- Test 2: Invalid Clickstream (null session_id) ---{NC}")
        invalid_click = send_invalid_clickstream()
        container_click = get_terraform_output("quarantine_container_clickstream")

        result = check_quarantine_storage(container_click, invalid_click['test_marker'])
        if result:
            tests_passed += 1
            print(f"{GREEN}✓ Invalid clickstream correctly quarantined{NC}")
        else:
            tests_failed += 1
            print(f"{RED}✗ Invalid clickstream not found in quarantine{NC}")

        # Summary
        print(f"\n{CYAN}{'='*60}{NC}")
        if tests_failed == 0:
            print(f"{GREEN}✓ All {tests_passed} tests passed!{NC}")
            print(f"{GREEN}{'='*60}{NC}")
            print(f"\n📄 Report saved: {report_path}\n")
        else:
            print(f"{RED}✗ {tests_failed} test(s) failed, {tests_passed} passed{NC}")
            print(f"{RED}{'='*60}{NC}\n")
            sys.exit(1)

    finally:
        output_buffer.save()
        sys.stdout = output_buffer.original_stdout


if __name__ == "__main__":
    main()

