#!/usr/bin/env python3
"""
Test Base Schema
================

This script validates the base schema after initial deployment:
- Checks that all base tables exist
- Shows table structure and sample data
- Generates a detailed report

Usage:
    uv run --directory scripts python tests/test_base_schema.py
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
    CYAN = '\033[0;36m'
    NC = '\033[0m'

def print_header(text):
    print(f"\n{Colors.BLUE}{'━' * 70}{Colors.NC}")
    print(f"{Colors.BLUE}  {text}{Colors.NC}")
    print(f"{Colors.BLUE}{'━' * 70}{Colors.NC}\n")

def print_success(text):
    print(f"{Colors.GREEN}✓{Colors.NC} {text}")

def print_error(text):
    print(f"{Colors.RED}✗{Colors.NC} {text}")

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

def format_table(headers, rows, max_rows=5):
    """Format data as ASCII table"""
    if not rows:
        return "  (empty table)"
    
    # Calculate column widths
    col_widths = [len(str(h)) for h in headers]
    for row in rows[:max_rows]:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val)))
    
    # Build table
    lines = []
    
    # Header
    header_line = "  " + " | ".join(str(h).ljust(w) for h, w in zip(headers, col_widths))
    lines.append(header_line)
    lines.append("  " + "-+-".join("-" * w for w in col_widths))
    
    # Rows
    for row in rows[:max_rows]:
        row_line = "  " + " | ".join(str(v).ljust(w) for v, w in zip(row, col_widths))
        lines.append(row_line)
    
    if len(rows) > max_rows:
        lines.append(f"  ... ({len(rows) - max_rows} more rows)")
    
    return "\n".join(lines)

def main():
    """Main test function"""
    
    print_header("TEST BASE SCHEMA")
    
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
    
    # Prepare report
    report_lines = []
    report_lines.append("=" * 70)
    report_lines.append("  BASE SCHEMA REPORT")
    report_lines.append("=" * 70)
    report_lines.append(f"\nDate: {datetime.now()}")
    report_lines.append(f"Server: {server}")
    report_lines.append(f"Database: {database}")
    report_lines.append("\n" + "=" * 70)
    
    tests_passed = 0
    tests_failed = 0
    
    # =========================================================================
    # TEST 1: Base tables
    # =========================================================================
    
    print_header("BASE TABLES")
    report_lines.append("\n\nBASE TABLES")
    report_lines.append("-" * 70)
    
    base_tables = ['dim_customer', 'dim_product', 'fact_order', 'fact_clickstream']
    
    for table in base_tables:
        try:
            result = execute_sql(conn, f"SELECT COUNT(*) FROM {table}")
            count = result[0][0]
            print_success(f"{table}: {count} rows")
            report_lines.append(f"✓ {table}: {count} rows")
            tests_passed += 1
            
            # Get sample data
            result = execute_sql(conn, f"SELECT TOP 3 * FROM {table}")
            if result:
                columns = [desc[0] for desc in conn.cursor().execute(f"SELECT TOP 1 * FROM {table}").description]
                report_lines.append(f"\n  Sample data from {table}:")
                report_lines.append(format_table(columns, result))
                report_lines.append("")
        except Exception as e:
            print_error(f"{table}: {e}")
            report_lines.append(f"✗ {table}: ERROR - {e}")
            tests_failed += 1
    
    # =========================================================================
    # TEST 2: Table structures
    # =========================================================================
    
    print_header("TABLE STRUCTURES")
    report_lines.append("\n\nTABLE STRUCTURES")
    report_lines.append("-" * 70)
    
    for table in base_tables:
        try:
            result = execute_sql(conn, f"""
                SELECT 
                    COLUMN_NAME,
                    DATA_TYPE,
                    CHARACTER_MAXIMUM_LENGTH,
                    IS_NULLABLE
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_NAME = '{table}'
                ORDER BY ORDINAL_POSITION
            """)
            
            report_lines.append(f"\n{table}:")
            for col in result:
                col_name, data_type, max_len, nullable = col
                length_str = f"({max_len})" if max_len else ""
                null_str = "NULL" if nullable == "YES" else "NOT NULL"
                report_lines.append(f"  - {col_name}: {data_type}{length_str} {null_str}")
            
            tests_passed += 1
        except Exception as e:
            print_error(f"Error getting structure for {table}: {e}")
            tests_failed += 1
    
    # =========================================================================
    # SUMMARY
    # =========================================================================
    
    conn.close()
    
    print_header("SUMMARY")
    
    total_tests = tests_passed + tests_failed
    success_rate = (tests_passed / total_tests * 100) if total_tests > 0 else 0
    
    summary = f"""
Total tests: {total_tests}
Passed: {tests_passed}
Failed: {tests_failed}
Success rate: {success_rate:.1f}%
"""
    
    print(summary)
    
    report_lines.append("\n\n" + "=" * 70)
    report_lines.append("SUMMARY")
    report_lines.append("=" * 70)
    report_lines.append(summary)
    
    # Save report
    report_file = f"base_schema_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, 'w') as f:
        f.write('\n'.join(report_lines))
    
    print(f"\n{Colors.GREEN}📄 Report saved: {report_file}{Colors.NC}\n")
    
    if tests_failed == 0:
        print(f"{Colors.GREEN}{'━' * 70}{Colors.NC}")
        print(f"{Colors.GREEN}  ✓ ALL TESTS PASSED{Colors.NC}")
        print(f"{Colors.GREEN}{'━' * 70}{Colors.NC}")
        return 0
    else:
        print(f"{Colors.RED}{'━' * 70}{Colors.NC}")
        print(f"{Colors.RED}  ✗ SOME TESTS FAILED{Colors.NC}")
        print(f"{Colors.RED}{'━' * 70}{Colors.NC}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
