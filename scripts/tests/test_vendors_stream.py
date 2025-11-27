#!/usr/bin/env python3
"""
Test Vendors Stream
===================

Test that vendor events are properly streamed and processed.

Usage:
    uv run --directory scripts python tests/test_vendors_stream.py
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
    result = sh.terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
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

def check_vendors_eventhub():
    """Check if vendors Event Hub exists"""
    print(f"{CYAN}🔍 Checking vendors Event Hub...{NC}")
    try:
        namespace = get_terraform_output("eventhub_namespace_name")
        result = sh.az("eventhubs", "eventhub", "show",
                      "--namespace-name", namespace,
                      "--name", "vendors",
                      "--resource-group", f"rg-e6-{os.getenv('TF_VAR_username')}",
                      "--query", "name",
                      "-o", "tsv")
        print(f"{GREEN}✓ Vendors Event Hub exists{NC}")
        return True
    except Exception as e:
        print(f"{RED}✗ Vendors Event Hub not found{NC}")
        print(f"{YELLOW}💡 Run: make stream-new-vendors{NC}")
        return False

def send_vendor_event():
    """Send a test vendor event"""
    print(f"{CYAN}📤 Sending test vendor event...{NC}")
    
    # Get Event Hub connection string
    connection_string = get_terraform_output("eventhub_send_connection_string")
    
    # Create vendor event
    vendor_event = {
        "vendor_id": f"TEST{int(time.time())}",
        "vendor_name": fake.company(),
        "vendor_status": "active",
        "vendor_category": fake.random_element(["electronics", "fashion", "home", "sports"]),
        "vendor_email": fake.company_email(),
        "commission_rate": round(fake.random.uniform(10.0, 25.0), 2),
        "timestamp": int(time.time())
    }
    
    print(f"  Vendor: {vendor_event['vendor_name']}")
    print(f"  ID: {vendor_event['vendor_id']}")
    
    # Send to Event Hub
    producer = EventHubProducerClient.from_connection_string(
        connection_string,
        eventhub_name="vendors"
    )
    
    with producer:
        event_data_batch = producer.create_batch()
        event_data_batch.add(EventData(json.dumps(vendor_event)))
        producer.send_batch(event_data_batch)
    
    print(f"{GREEN}✓ Event sent{NC}")
    return vendor_event

def wait_for_processing(vendor_id, max_wait=60):
    """Wait for vendor to appear in database"""
    print(f"{CYAN}⏳ Waiting for Stream Analytics to process (max {max_wait}s)...{NC}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    start_time = time.time()
    while time.time() - start_time < max_wait:
        cursor.execute(
            "SELECT COUNT(*) FROM dim_vendor WHERE vendor_id = ?",
            vendor_id
        )
        count = cursor.fetchone()[0]
        
        if count > 0:
            elapsed = int(time.time() - start_time)
            print(f"{GREEN}✓ Vendor processed in {elapsed}s{NC}")
            return True
        
        time.sleep(2)
        print(".", end="", flush=True)
    
    print(f"\n{RED}✗ Timeout waiting for vendor{NC}")
    return False

def verify_vendor_data(vendor_event):
    """Verify vendor data in database"""
    print(f"{CYAN}🔍 Verifying vendor data...{NC}")
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT vendor_id, vendor_name, vendor_status, vendor_category, 
               vendor_email, commission_rate, is_current
        FROM dim_vendor 
        WHERE vendor_id = ?
    """, vendor_event['vendor_id'])
    
    row = cursor.fetchone()
    if not row:
        print(f"{RED}✗ Vendor not found in database{NC}")
        return False
    
    # Verify fields
    checks = [
        (row.vendor_id == vendor_event['vendor_id'], "vendor_id"),
        (row.vendor_name == vendor_event['vendor_name'], "vendor_name"),
        (row.vendor_status == vendor_event['vendor_status'], "vendor_status"),
        (row.vendor_category == vendor_event['vendor_category'], "vendor_category"),
        (row.vendor_email == vendor_event['vendor_email'], "vendor_email"),
        (abs(row.commission_rate - vendor_event['commission_rate']) < 0.01, "commission_rate"),
        (row.is_current == 1, "is_current"),
    ]
    
    all_passed = True
    for passed, field in checks:
        status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
        print(f"  {status} {field}")
        if not passed:
            all_passed = False
    
    return all_passed

def main():
    """Main test function"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test: Vendors Stream Processing{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")
    
    # Check if vendors Event Hub exists
    if not check_vendors_eventhub():
        sys.exit(1)
    
    # Send test event
    vendor_event = send_vendor_event()
    
    # Wait for processing
    if not wait_for_processing(vendor_event['vendor_id']):
        sys.exit(1)
    
    # Verify data
    if not verify_vendor_data(vendor_event):
        sys.exit(1)
    
    print(f"\n{GREEN}{'='*60}{NC}")
    print(f"{GREEN}✓ All tests passed!{NC}")
    print(f"{GREEN}{'='*60}{NC}\n")

if __name__ == "__main__":
    main()
