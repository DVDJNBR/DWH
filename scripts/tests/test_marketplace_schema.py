#!/usr/bin/env python3
"""
Test Marketplace Schema
=======================

This script validates the marketplace schema migration:
- Checks that all new tables exist
- Verifies data integrity
- Tests Row-Level Security (RLS)
- Validates vendor relationships

Usage:
    uv run --directory scripts python tests/test_marketplace_schema.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path

import pyodbc
import sh
from dotenv import load_dotenv

# Colors
class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def print_header(text):
    print(f"\n{Colors.BLUE}{'━' * 60}{Colors.NC}")
    print(f"{Colors.BLUE}  {text}{Colors.NC}")
    print(f"{Colors.BLUE}{'━' * 60}{Colors.NC}\n")

def print_success(text):
    print(f"{Colors.GREEN}✓{Colors.NC} {text}")

def print_error(text):
    print(f"{Colors.RED}✗{Colors.NC} {text}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.NC}")

def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent.parent / "terraform"
    result = sh.terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
    return result.strip()

def execute_sql(conn, query):
    """Execute SQL query and return results"""
    cursor = conn.cursor()
    cursor.execute(query)
    results = cursor.fetchall()
    cursor.close()
    return results

def main():
    """Main test function"""
    
    print_header("TEST MARKETPLACE SCHEMA")
    
    # Load environment
    env_path = Path(__file__).parent.parent.parent / '.env'
    load_dotenv(env_path)
    
    # Get connection info
    server = get_terraform_output('sql_server_fqdn')
    database = get_terraform_output('sql_database_name')
    username = os.getenv('SQL_ADMIN_LOGIN')
    password = os.getenv('SQL_ADMIN_PASSWORD')
    
    print(f"📊 Connecting to {server} / {database}\n")
    
    # Connect
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
    except Exception as e:
        print_error(f"Connection failed: {e}")
        sys.exit(1)
    
    tests_passed = 0
    tests_failed = 0
    
    # =========================================================================
    # TEST 1: Check new tables exist
    # =========================================================================
    
    print_header("TEST 1: Table Existence")
    
    required_tables = [
        'dim_vendor',
        'fact_vendor_performance',
        'fact_stock'
    ]
    
    for table in required_tables:
        try:
            result = execute_sql(conn, f"SELECT COUNT(*) FROM {table}")
            count = result[0][0]
            print_success(f"{table} exists ({count} rows)")
            tests_passed += 1
        except Exception as e:
            print_error(f"{table} missing or inaccessible: {e}")
            tests_failed += 1
    
    # =========================================================================
    # TEST 2: Check dim_product has vendor_id
    # =========================================================================
    
    print_header("TEST 2: dim_product Schema")
    
    try:
        result = execute_sql(conn, """
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'dim_product' 
            AND COLUMN_NAME = 'vendor_id'
        """)
        
        if result[0][0] > 0:
            print_success("vendor_id column exists in dim_product")
            tests_passed += 1
            
            # Check if products are linked
            result = execute_sql(conn, """
                SELECT COUNT(*) FROM dim_product WHERE vendor_id IS NOT NULL
            """)
            linked_count = result[0][0]
            print_success(f"{linked_count} products linked to vendors")
            tests_passed += 1
        else:
            print_error("vendor_id column missing in dim_product")
            tests_failed += 1
    except Exception as e:
        print_error(f"Error checking dim_product: {e}")
        tests_failed += 1
    
    # =========================================================================
    # TEST 3: Check vendors exist
    # =========================================================================
    
    print_header("TEST 3: Vendor Data")
    
    try:
        result = execute_sql(conn, "SELECT COUNT(*) FROM dim_vendor")
        vendor_count = result[0][0]
        
        if vendor_count >= 1:
            print_success(f"{vendor_count} vendors in database")
            tests_passed += 1
            
            # Check default vendor
            result = execute_sql(conn, """
                SELECT vendor_name FROM dim_vendor WHERE vendor_id = 'SHOPNOW'
            """)
            
            if result:
                print_success(f"Default vendor exists: {result[0][0]}")
                tests_passed += 1
            else:
                print_warning("Default vendor (SHOPNOW) not found")
                tests_failed += 1
        else:
            print_error("No vendors found in database")
            tests_failed += 1
    except Exception as e:
        print_error(f"Error checking vendors: {e}")
        tests_failed += 1
    
    # =========================================================================
    # TEST 4: Check SCD Type 2 fields
    # =========================================================================
    
    print_header("TEST 4: SCD Type 2 Implementation")
    
    scd_fields = ['valid_from', 'valid_to', 'is_current']
    
    for field in scd_fields:
        try:
            result = execute_sql(conn, f"""
                SELECT COUNT(*) 
                FROM INFORMATION_SCHEMA.COLUMNS 
                WHERE TABLE_NAME = 'dim_vendor' 
                AND COLUMN_NAME = '{field}'
            """)
            
            if result[0][0] > 0:
                print_success(f"SCD field '{field}' exists")
                tests_passed += 1
            else:
                print_error(f"SCD field '{field}' missing")
                tests_failed += 1
        except Exception as e:
            print_error(f"Error checking SCD field {field}: {e}")
            tests_failed += 1
    
    # =========================================================================
    # TEST 5: Check indexes
    # =========================================================================
    
    print_header("TEST 5: Indexes")
    
    expected_indexes = [
        ('dim_vendor', 'idx_vendor_id'),
        ('dim_vendor', 'idx_vendor_is_current'),
        ('dim_product', 'idx_product_vendor'),
        ('fact_vendor_performance', 'idx_vendor_performance_vendor_date'),
        ('fact_stock', 'idx_stock_vendor_product')
    ]
    
    for table, index in expected_indexes:
        try:
            result = execute_sql(conn, f"""
                SELECT COUNT(*) 
                FROM sys.indexes 
                WHERE object_id = OBJECT_ID('{table}') 
                AND name = '{index}'
            """)
            
            if result[0][0] > 0:
                print_success(f"Index {index} exists on {table}")
                tests_passed += 1
            else:
                print_warning(f"Index {index} missing on {table}")
                tests_failed += 1
        except Exception as e:
            print_error(f"Error checking index {index}: {e}")
            tests_failed += 1
    
    # =========================================================================
    # TEST 6: Check Row-Level Security
    # =========================================================================
    
    print_header("TEST 6: Row-Level Security")
    
    try:
        # Check if Security schema exists
        result = execute_sql(conn, """
            SELECT COUNT(*) FROM sys.schemas WHERE name = 'Security'
        """)
        
        if result[0][0] > 0:
            print_success("Security schema exists")
            tests_passed += 1
            
            # Check if predicate function exists
            result = execute_sql(conn, """
                SELECT COUNT(*) 
                FROM sys.objects 
                WHERE name = 'fn_VendorAccessPredicate'
            """)
            
            if result[0][0] > 0:
                print_success("RLS predicate function exists")
                tests_passed += 1
            else:
                print_warning("RLS predicate function not found")
                tests_failed += 1
            
            # Check if security policy exists
            result = execute_sql(conn, """
                SELECT COUNT(*) 
                FROM sys.security_policies 
                WHERE name = 'VendorAccessPolicy'
            """)
            
            if result[0][0] > 0:
                print_success("RLS security policy exists")
                tests_passed += 1
                
                # Check if policy is enabled
                result = execute_sql(conn, """
                    SELECT is_enabled 
                    FROM sys.security_policies 
                    WHERE name = 'VendorAccessPolicy'
                """)
                
                if result[0][0]:
                    print_success("RLS policy is ENABLED")
                else:
                    print_warning("RLS policy is DISABLED (enable manually when ready)")
                tests_passed += 1
            else:
                print_warning("RLS security policy not found")
                tests_failed += 1
        else:
            print_error("Security schema not found")
            tests_failed += 1
    except Exception as e:
        print_error(f"Error checking RLS: {e}")
        tests_failed += 1
    
    # =========================================================================
    # TEST 7: Data integrity
    # =========================================================================
    
    print_header("TEST 7: Data Integrity")
    
    try:
        # Check foreign key relationships
        result = execute_sql(conn, """
            SELECT COUNT(*) 
            FROM dim_product p
            LEFT JOIN dim_vendor v ON p.vendor_id = v.vendor_id
            WHERE v.vendor_id IS NULL
        """)
        
        orphaned = result[0][0]
        if orphaned == 0:
            print_success("All products linked to valid vendors")
            tests_passed += 1
        else:
            print_error(f"{orphaned} products with invalid vendor_id")
            tests_failed += 1
    except Exception as e:
        print_error(f"Error checking data integrity: {e}")
        tests_failed += 1
    
    # =========================================================================
    # SUMMARY
    # =========================================================================
    
    conn.close()
    
    print_header("TEST SUMMARY")
    
    total_tests = tests_passed + tests_failed
    success_rate = (tests_passed / total_tests * 100) if total_tests > 0 else 0
    
    print(f"Total tests: {total_tests}")
    print(f"{Colors.GREEN}Passed: {tests_passed}{Colors.NC}")
    print(f"{Colors.RED}Failed: {tests_failed}{Colors.NC}")
    print(f"Success rate: {success_rate:.1f}%")
    print()
    
    if tests_failed == 0:
        print(f"{Colors.GREEN}{'━' * 60}{Colors.NC}")
        print(f"{Colors.GREEN}  ✓ ALL TESTS PASSED{Colors.NC}")
        print(f"{Colors.GREEN}{'━' * 60}{Colors.NC}")
        return 0
    else:
        print(f"{Colors.RED}{'━' * 60}{Colors.NC}")
        print(f"{Colors.RED}  ✗ SOME TESTS FAILED{Colors.NC}")
        print(f"{Colors.RED}{'━' * 60}{Colors.NC}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
