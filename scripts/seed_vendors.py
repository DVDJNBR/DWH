#!/usr/bin/env python3
"""
Seed Vendors
============

Generate realistic vendor data using Faker.

Usage:
    uv run --directory scripts python seed_vendors.py --count 10
"""

import argparse
import os
import sys
from pathlib import Path

import pyodbc
import sh
from dotenv import load_dotenv
from faker import Faker

# Load environment
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent / "terraform"
    terraform = getattr(sh, "terraform")
    result = terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
    return result.strip()

def generate_vendor_id(company_name):
    """Generate vendor_id from company name"""
    # Remove common suffixes and special chars
    clean = company_name.upper()
    for suffix in [' LLC', ' INC', ' GROUP', ' LTD', ' CORP', ' CO', ',', '.', '-']:
        clean = clean.replace(suffix, '')
    
    # Take first 3 letters of each word, max 10 chars
    words = clean.split()
    if len(words) == 1:
        return words[0][:10]
    else:
        return ''.join(w[:3] for w in words[:3])[:10]

def seed_vendors(count=10):
    """Generate and insert vendor data"""
    
    fake = Faker()
    
    # Get connection info
    server = get_terraform_output('sql_server_fqdn')
    database = get_terraform_output('sql_database_name')
    username = os.getenv('SQL_ADMIN_LOGIN')
    password = os.getenv('SQL_ADMIN_PASSWORD')
    
    print(f"📊 Connecting to {server} / {database}")
    
    connection_string = (
        f'DRIVER={{ODBC Driver 18 for SQL Server}};'
        f'SERVER={server};'
        f'DATABASE={database};'
        f'UID={username};'
        f'PWD={password};'
        f'Encrypt=yes;'
        f'TrustServerCertificate=no;'
    )
    
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        
        print(f"\n🏪 Generating {count} vendors...")
        
        categories = ['electronics', 'fashion', 'home', 'sports', 'books', 'toys', 'food']
        statuses = ['active'] * 8 + ['pending'] * 2  # 80% active, 20% pending
        
        vendors_created = 0
        vendors_skipped = 0
        
        for i in range(count):
            company_name = fake.company()
            vendor_id = generate_vendor_id(company_name)
            
            # Check if vendor_id already exists
            cursor.execute("SELECT COUNT(*) FROM dim_vendor WHERE vendor_id = ?", vendor_id)
            row = cursor.fetchone()
            if row and row[0] > 0:
                print(f"  ⚠️  Skipped {vendor_id} (already exists)")
                vendors_skipped += 1
                continue
            
            category = fake.random_element(categories)
            status = fake.random_element(statuses)
            email = f"contact@{vendor_id.lower()}.com"
            phone = fake.phone_number()[:50]  # Limit to 50 chars
            commission_rate = round(fake.random.uniform(10.0, 25.0), 2)
            
            cursor.execute("""
                INSERT INTO dim_vendor (
                    vendor_id, vendor_name, vendor_status, vendor_category,
                    vendor_email, vendor_phone, commission_rate,
                    valid_from, is_current
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, GETDATE(), 1)
            """, vendor_id, company_name, status, category, email, phone, commission_rate)
            
            print(f"  ✓ {vendor_id}: {company_name} ({category}, {commission_rate}%)")
            vendors_created += 1
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print(f"\n✅ Created {vendors_created} vendors")
        if vendors_skipped > 0:
            print(f"⚠️  Skipped {vendors_skipped} vendors (already exist)")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate vendor data')
    parser.add_argument('--count', type=int, default=10, help='Number of vendors to generate')
    args = parser.parse_args()
    
    seed_vendors(args.count)
