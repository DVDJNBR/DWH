#!/usr/bin/env python3
"""
Test SCD Type 2 Implementation for dim_vendor
==============================================

Tests the complete SCD Type 2 flow:
1. Insert new vendor → stg_vendor → trigger → dim_vendor (is_current=1)
2. Update vendor → stg_vendor → trigger → old record closed (is_current=0) + new record (is_current=1)
3. Verify historization works correctly

Usage:
    uv run --directory scripts python tests/test_scd2_vendor.py
"""

import json
import os
import sys
import time
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
    result = sh.terraform(f"-chdir={str(terraform_dir)}", "output", "-raw", key)
    return result.strip()

def get_db_connection():
    """Create database connection"""
    server = get_terraform_output("sql_server_fqdn")
    database = get_terraform_output("sql_database_name")
    username = os.getenv("SQL_ADMIN_LOGIN")
    password = os.getenv("SQL_ADMIN_PASSWORD")

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

def send_vendor_event(vendor_data):
    """Send vendor event to Event Hub"""
    namespace = get_terraform_output("eventhub_namespace")
    rg = get_terraform_output("resource_group_name")

    connection_string = sh.az(
        "eventhubs", "namespace", "authorization-rule", "keys", "list",
        "--namespace-name", namespace,
        "--name", "send-policy",
        "--resource-group", rg,
        "--query", "primaryConnectionString",
        "-o", "tsv"
    ).strip()

    producer = EventHubProducerClient.from_connection_string(
        connection_string,
        eventhub_name="vendors"
    )

    with producer:
        event_data_batch = producer.create_batch()
        event_data_batch.add(EventData(json.dumps(vendor_data)))
        producer.send_batch(event_data_batch)

def wait_for_dim_vendor(vendor_id, max_wait=60):
    """Wait for vendor to appear in dim_vendor"""
    conn = get_db_connection()
    cursor = conn.cursor()

    start_time = time.time()
    while time.time() - start_time < max_wait:
        cursor.execute(
            "SELECT COUNT(*) FROM dim_vendor WHERE vendor_id = ? AND is_current = 1",
            vendor_id
        )
        count = cursor.fetchone()[0]

        if count > 0:
            return True

        time.sleep(2)
        print(".", end="", flush=True)

    return False

def get_vendor_history(vendor_id):
    """Get all vendor records (current and historical)"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT vendor_key, vendor_name, vendor_status, vendor_email,
               commission_rate, valid_from, valid_to, is_current
        FROM dim_vendor
        WHERE vendor_id = ?
        ORDER BY valid_from
    """, vendor_id)

    return cursor.fetchall()

def test_new_vendor_insert():
    """Test 1: Insert new vendor"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test 1: Insert New Vendor{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    vendor_id = f"SCD2_TEST_{int(time.time())}"
    vendor_data = {
        "vendor_id": vendor_id,
        "vendor_name": "Test Vendor Initial",
        "vendor_status": "active",
        "vendor_category": "electronics",
        "vendor_email": "initial@test.com",
        "commission_rate": 15.00,
        "timestamp": int(time.time())
    }

    print(f"{CYAN}📤 Sending new vendor event...{NC}")
    print(f"  Vendor ID: {vendor_id}")
    print(f"  Name: {vendor_data['vendor_name']}")

    send_vendor_event(vendor_data)
    print(f"{GREEN}✓ Event sent{NC}")

    print(f"{CYAN}⏳ Waiting for processing...{NC}", end="", flush=True)
    if not wait_for_dim_vendor(vendor_id):
        print(f"\n{RED}✗ Timeout waiting for vendor{NC}")
        return False, vendor_id

    print(f"\n{GREEN}✓ Vendor processed{NC}")

    # Verify
    history = get_vendor_history(vendor_id)
    if len(history) != 1:
        print(f"{RED}✗ Expected 1 record, got {len(history)}{NC}")
        return False, vendor_id

    record = history[0]
    checks = [
        (record.vendor_name == "Test Vendor Initial", "vendor_name"),
        (record.is_current == 1, "is_current = 1"),
        (record.valid_to is None, "valid_to is NULL")
    ]

    all_passed = True
    for passed, field in checks:
        status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
        print(f"  {status} {field}")
        if not passed:
            all_passed = False

    return all_passed, vendor_id

def test_vendor_update(vendor_id):
    """Test 2: Update existing vendor (SCD Type 2)"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test 2: Update Vendor (SCD Type 2 Historization){NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    time.sleep(2)  # Ensure different timestamp

    vendor_data = {
        "vendor_id": vendor_id,
        "vendor_name": "Test Vendor UPDATED",
        "vendor_status": "active",
        "vendor_category": "electronics",
        "vendor_email": "updated@test.com",
        "commission_rate": 20.00,
        "timestamp": int(time.time())
    }

    print(f"{CYAN}📤 Sending update event...{NC}")
    print(f"  Vendor ID: {vendor_id}")
    print(f"  New Name: {vendor_data['vendor_name']}")
    print(f"  New Email: {vendor_data['vendor_email']}")
    print(f"  New Commission: {vendor_data['commission_rate']}%")

    send_vendor_event(vendor_data)
    print(f"{GREEN}✓ Event sent{NC}")

    print(f"{CYAN}⏳ Waiting for SCD Type 2 processing...{NC}")
    time.sleep(10)  # Wait for trigger to process

    # Verify historization
    history = get_vendor_history(vendor_id)

    print(f"\n{CYAN}📊 Vendor History:{NC}")
    for i, record in enumerate(history, 1):
        print(f"  Record {i}:")
        print(f"    Name: {record.vendor_name}")
        print(f"    Email: {record.vendor_email}")
        print(f"    Commission: {record.commission_rate}%")
        print(f"    is_current: {record.is_current}")
        print(f"    valid_from: {record.valid_from}")
        print(f"    valid_to: {record.valid_to}")

    if len(history) != 2:
        print(f"\n{RED}✗ Expected 2 records (1 historical + 1 current), got {len(history)}{NC}")
        return False

    # Verify old record (historical)
    old_record = history[0]
    checks_old = [
        (old_record.vendor_name == "Test Vendor Initial", "Old record: vendor_name"),
        (old_record.is_current == 0, "Old record: is_current = 0"),
        (old_record.valid_to is not None, "Old record: valid_to is NOT NULL"),
    ]

    # Verify new record (current)
    new_record = history[1]
    checks_new = [
        (new_record.vendor_name == "Test Vendor UPDATED", "New record: vendor_name"),
        (new_record.vendor_email == "updated@test.com", "New record: vendor_email"),
        (abs(float(new_record.commission_rate) - 20.00) < 0.01, "New record: commission_rate"),
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

def cleanup_test_vendor(vendor_id):
    """Cleanup test vendor data"""
    print(f"\n{CYAN}🧹 Cleaning up test data...{NC}")
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("DELETE FROM dim_vendor WHERE vendor_id = ?", vendor_id)
    cursor.execute("DELETE FROM stg_vendor WHERE vendor_id = ?", vendor_id)
    conn.commit()

    print(f"{GREEN}✓ Cleanup complete{NC}")

def main():
    """Main test function"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}SCD Type 2 Implementation Test Suite{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    # Test 1: Insert
    success1, vendor_id = test_new_vendor_insert()
    if not success1:
        cleanup_test_vendor(vendor_id)
        sys.exit(1)

    # Test 2: Update (SCD Type 2)
    success2 = test_vendor_update(vendor_id)

    # Cleanup
    cleanup_test_vendor(vendor_id)

    # Final result
    if success1 and success2:
        print(f"\n{GREEN}{'='*60}{NC}")
        print(f"{GREEN}✓ All SCD Type 2 tests passed!{NC}")
        print(f"{GREEN}{'='*60}{NC}\n")
        return 0
    else:
        print(f"\n{RED}{'='*60}{NC}")
        print(f"{RED}✗ Some tests failed{NC}")
        print(f"{RED}{'='*60}{NC}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
