#!/usr/bin/env python3
"""
Test SCD Type 2 Implementation for dim_product
==============================================

Tests the complete SCD Type 2 flow for products:
1.  Send an order with a new product -> stg_product -> trigger -> dim_product (is_current=1)
2.  Send another order with updated product info -> stg_product -> trigger -> old record closed (is_current=0) + new record (is_current=1)
3.  Verify historization works correctly

Usage:
    make test-scd2-product
"""

import json
import os
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path

import pyodbc
import sh
from azure.eventhub import EventData, EventHubProducerClient
from dotenv import load_dotenv
from faker import Faker

# Load environment
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

# Colors
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
RED = '\033[0;31m'
CYAN = '\033[0;36m'
NC = '\033[0m'

fake = Faker()

def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent.parent / "terraform"
    try:
        result = sh.terraform(f"-chdir={str(terraform_dir)}", "output", "-raw", key)
        return result.strip()
    except sh.ErrorReturnCode as e:
        print(f"{RED}Error getting Terraform output for '{key}': {e}{NC}")
        sys.exit(1)

def get_db_connection():
    """Create database connection"""
    server = get_terraform_output("sql_server_fqdn")
    database = get_terraform_output("sql_database_name")
    username = os.getenv("SQL_ADMIN_LOGIN")
    password = os.getenv("SQL_ADMIN_PASSWORD")

    if not all([server, database, username, password]):
        print(f"{RED}Database connection details are missing. Check your .env file.{NC}")
        sys.exit(1)

    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )
    return pyodbc.connect(conn_str)

def send_order_event(product_data):
    """Send an order event containing product data to Event Hub"""
    namespace = get_terraform_output("eventhub_namespace")
    rg = get_terraform_output("resource_group_name")

    try:
        connection_string = sh.az(
            "eventhubs", "namespace", "authorization-rule", "keys", "list",
            "--namespace-name", namespace,
            "--name", "send-policy",
            "--resource-group", rg,
            "--query", "primaryConnectionString",
            "-o", "tsv"
        ).strip()
    except sh.ErrorReturnCode as e:
        print(f"{RED}Failed to get Event Hub connection string: {e}{NC}")
        sys.exit(1)

    producer = EventHubProducerClient.from_connection_string(
        connection_string,
        eventhub_name="orders"
    )

    order_event = {
        "order_id": str(uuid.uuid4()),
        "customer": {
            "id": str(uuid.uuid4()),
            "name": fake.name(),
            "email": fake.email(),
            "address": fake.street_address(),
            "city": fake.city(),
            "country": fake.country()
        },
        "items": [product_data],
        "status": "completed",
        "timestamp": int(time.time())
    }

    with producer:
        event_data_batch = producer.create_batch()
        event_data_batch.add(EventData(json.dumps(order_event)))
        producer.send_batch(event_data_batch)

def wait_for_dim_product(product_id, max_wait=60):
    """Wait for product to appear in dim_product"""
    conn = get_db_connection()
    cursor = conn.cursor()

    start_time = time.time()
    while time.time() - start_time < max_wait:
        cursor.execute(
            "SELECT COUNT(*) FROM dim_product WHERE product_id = ? AND is_current = 1",
            product_id
        )
        count = cursor.fetchone()[0]

        if count > 0:
            return True

        time.sleep(2)
        print(".", end="", flush=True)

    return False

def get_product_history(product_id):
    """Get all product records (current and historical)"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT product_key, name, category, vendor_id,
               valid_from, valid_to, is_current
        FROM dim_product
        WHERE product_id = ?
        ORDER BY valid_from
    """, product_id)

    return cursor.fetchall()

def test_new_product_insert():
    """Test 1: Insert new product via an order event"""
    print(f"{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test 1: Insert New Product{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    product_id = f"SCD2_PROD_TEST_{int(time.time())}"
    product_data = {
        "product_id": product_id,
        "name": "Test Product Initial",
        "category": "Gadgets",
        "vendor_id": "SHOPNOW",
        "quantity": 1,
        "unit_price": 99.99
    }

    print(f"{CYAN}📤 Sending new order event with product...{NC}")
    print(f"  Product ID: {product_id}")
    print(f"  Name: {product_data['name']}")

    send_order_event(product_data)
    print(f"{GREEN}✓ Event sent{NC}")

    print(f"{CYAN}⏳ Waiting for processing...{NC}", end="", flush=True)
    if not wait_for_dim_product(product_id):
        print(f"\n{RED}✗ Timeout waiting for product{NC}")
        return False, product_id

    print(f"\n{GREEN}✓ Product processed{NC}")

    # Verify
    history = get_product_history(product_id)
    if len(history) != 1:
        print(f"{RED}✗ Expected 1 record, got {len(history)}{NC}")
        return False, product_id

    record = history[0]
    checks = [
        (record.name == "Test Product Initial", "name"),
        (record.category == "Gadgets", "category"),
        (record.is_current == 1, "is_current = 1"),
        (record.valid_to is None, "valid_to is NULL")
    ]

    all_passed = True
    for passed, field in checks:
        status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
        print(f"  {status} {field}")
        if not passed:
            all_passed = False

    return all_passed, product_id

def test_product_update(product_id):
    """Test 2: Update existing product (SCD Type 2)"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test 2: Update Product (SCD Type 2 Historization){NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    time.sleep(2)  # Ensure different timestamp

    product_data = {
        "product_id": product_id,
        "name": "Test Product UPDATED",
        "category": "Advanced Gadgets",
        "vendor_id": "VENDOR_A",
        "quantity": 1,
        "unit_price": 109.99
    }

    print(f"{CYAN}📤 Sending update event via a new order...{NC}")
    print(f"  Product ID: {product_id}")
    print(f"  New Name: {product_data['name']}")
    print(f"  New Category: {product_data['category']}")

    send_order_event(product_data)
    print(f"{GREEN}✓ Event sent{NC}")

    print(f"{CYAN}⏳ Waiting for SCD Type 2 processing...{NC}")
    time.sleep(15)  # Wait for trigger to process

    # Verify historization
    history = get_product_history(product_id)

    print(f"\n{CYAN}📊 Product History:{NC}")
    for i, record in enumerate(history, 1):
        print(f"  Record {i}:")
        print(f"    Name: {record.name}")
        print(f"    Category: {record.category}")
        print(f"    is_current: {record.is_current}")
        print(f"    valid_from: {record.valid_from}")
        print(f"    valid_to: {record.valid_to}")

    if len(history) != 2:
        print(f"\n{RED}✗ Expected 2 records (1 historical + 1 current), got {len(history)}{NC}")
        return False

    # Verify old record (historical)
    old_record = history[0]
    checks_old = [
        (old_record.name == "Test Product Initial", "Old record: name"),
        (old_record.category == "Gadgets", "Old record: category"),
        (old_record.is_current == 0, "Old record: is_current = 0"),
        (old_record.valid_to is not None, "Old record: valid_to is NOT NULL"),
    ]

    # Verify new record (current)
    new_record = history[1]
    checks_new = [
        (new_record.name == "Test Product UPDATED", "New record: name"),
        (new_record.category == "Advanced Gadgets", "New record: category"),
        (new_record.is_current == 1, "New record: is_current = 1"),
        (new_record.valid_to is None, "New record: valid_to is NULL"),
    ]

    print(f"\n{CYAN}✅ Verification:{NC}")
    all_passed = True
    for passed, field in checks_old + checks_new:
        status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
        print(f"  {status} {field}")
        if not passed:
            all_passed = False

    return all_passed

def cleanup_test_product(product_id):
    """Cleanup test product data"""
    print(f"\n{CYAN}🧹 Cleaning up test data...{NC}")
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("DELETE FROM dim_product WHERE product_id = ?", product_id)
        cursor.execute("DELETE FROM stg_product WHERE product_id = ?", product_id)
        conn.commit()
        print(f"{GREEN}✓ Cleanup complete{NC}")
    except pyodbc.Error as ex:
        sqlstate = ex.args[0]
        print(f"{RED}✗ Cleanup failed: {sqlstate}{NC}")


def main():
    """Main test function"""
    print(f"{CYAN}{'='*60}{NC}")
    print(f"{CYAN}SCD Type 2 for Products - Test Suite{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    # Test 1: Insert
    success1, product_id = test_new_product_insert()
    if not success1:
        cleanup_test_product(product_id)
        sys.exit(1)

    # Test 2: Update (SCD Type 2)
    success2 = test_product_update(product_id)

    # Cleanup
    cleanup_test_product(product_id)

    # Final result
    if success1 and success2:
        print(f"\n{GREEN}{'='*60}{NC}")
        print(f"{GREEN}✓ All SCD Type 2 product tests passed!{NC}")
        print(f"{GREEN}{'='*60}{NC}\n")
        return 0
    else:
        print(f"\n{RED}{'='*60}{NC}")
        print(f"{RED}✗ Some product tests failed{NC}")
        print(f"{RED}{'='*60}{NC}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
