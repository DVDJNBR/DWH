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

def check_vendors_eventhub():
    """Check if vendors Event Hub exists"""
    print(f"{CYAN}🔍 Checking vendors Event Hub...{NC}")
    try:
        namespace = get_terraform_output("eventhub_namespace")
        rg = get_terraform_output("resource_group_name")
        result = sh.az("eventhubs", "eventhub", "show",
                      "--namespace-name", namespace,
                      "--name", "vendors",
                      "--resource-group", rg,
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

    # Get Event Hub connection string via Azure CLI
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
        (abs(float(row.commission_rate) - vendor_event['commission_rate']) < 0.01, "commission_rate"),
        (row.is_current == 1, "is_current"),
    ]
    
    all_passed = True
    for passed, field in checks:
        status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
        print(f"  {status} {field}")
        if not passed:
            all_passed = False
    
    return all_passed

def show_recent_orders():
    """Show the 10 most recent orders with vendor and customer details"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}📊 Last 10 Orders (with vendor & customer joins){NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    conn = get_db_connection()
    cursor = conn.cursor()

    query = """
        SELECT TOP 10
            o.order_id,
            o.order_timestamp,
            c.name AS customer_name,
            c.city AS customer_city,
            p.name AS product_name,
            p.category AS product_category,
            v.vendor_name,
            v.vendor_category,
            o.quantity,
            o.unit_price,
            (o.quantity * o.unit_price) AS total_amount,
            v.commission_rate,
            ROUND((o.quantity * o.unit_price) * v.commission_rate / 100, 2) AS commission
        FROM fact_order o
        LEFT JOIN dim_customer c ON o.customer_id = c.customer_id
        LEFT JOIN dim_product p ON o.product_id = p.product_id
        LEFT JOIN dim_vendor v ON o.vendor_id = v.vendor_id AND v.is_current = 1
        ORDER BY o.order_timestamp DESC
    """

    cursor.execute(query)
    rows = cursor.fetchall()

    if not rows:
        print(f"{YELLOW}⚠ No orders found in database{NC}")
        return

    # Print each order
    for i, row in enumerate(rows, 1):
        print(f"{CYAN}─────────────────────────────────────────────────────────────{NC}")
        print(f"  {GREEN}Order #{i}{NC}: {row.order_id}")
        print(f"  📅 Date: {row.order_timestamp}")
        print(f"  👤 Customer: {row.customer_name or 'N/A'} ({row.customer_city or 'N/A'})")
        print(f"  📦 Product: {row.product_name or 'N/A'} [{row.product_category or 'N/A'}]")
        print(f"  🏪 Vendor: {row.vendor_name or 'N/A'} [{row.vendor_category or 'N/A'}]")
        unit_price = float(row.unit_price or 0)
        total_amount = float(row.total_amount or 0)
        print(f"  💰 {row.quantity or 0} x ${unit_price:.2f} = ${total_amount:.2f}")
        if row.commission_rate:
            print(f"  📈 Commission: {float(row.commission_rate):.1f}% = ${float(row.commission or 0):.2f}")

    print(f"{CYAN}─────────────────────────────────────────────────────────────{NC}")

    # Summary stats
    cursor.execute("""
        SELECT
            COUNT(*) as total_orders,
            COUNT(DISTINCT o.vendor_id) as vendor_count,
            SUM(o.quantity * o.unit_price) as total_revenue
        FROM fact_order o
    """)
    stats = cursor.fetchone()

    print(f"\n{CYAN}📊 Summary:{NC}")
    print(f"  Total orders: {stats.total_orders}")
    print(f"  Active vendors: {stats.vendor_count}")
    print(f"  Total revenue: ${float(stats.total_revenue or 0):,.2f}")

    conn.close()

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

    # Show recent orders with joins
    show_recent_orders()

    print(f"\n{GREEN}{'='*60}{NC}")
    print(f"{GREEN}✓ All tests passed!{NC}")
    print(f"{GREEN}{'='*60}{NC}\n")

if __name__ == "__main__":
    main()
