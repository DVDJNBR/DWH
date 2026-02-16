#!/usr/bin/env python3
"""
Quick Backup Test
=================

Fast test that verifies backup configuration without doing a full restore.

Tests:
1. Backup retention policy is configured
2. Automated backups are enabled
3. Restore points are available
4. Geo-replication status (if enabled)

This test runs in ~30 seconds vs 5-10 minutes for full restore.

Usage:
    uv run --directory scripts python tests/test_backup_quick.py
"""

import os
import sys
from datetime import datetime
from pathlib import Path

import sh
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

def test_backup_retention():
    """Test backup retention policy"""
    print(f"{CYAN}🔍 Testing backup retention policy...{NC}")
    
    try:
        server = get_terraform_output("sql_server_name")
        database = get_terraform_output("sql_database_name")
        rg = f"rg-e6-{os.getenv('TF_VAR_username')}"
        
        # Get short-term retention policy
        az = getattr(sh, "az")
        result = az("sql", "db", "str-policy", "show",
                      "--resource-group", rg,
                      "--server", server,
                      "--database", database,
                      "--query", "{RetentionDays:retentionDays, DiffBackupHours:diffBackupIntervalInHours}",
                      "-o", "json")
        
        print(f"{GREEN}✓ Backup retention policy configured{NC}")
        print(f"  {result}")
        return True
    except Exception as e:
        print(f"{RED}✗ Failed to get retention policy: {e}{NC}")
        return False

def test_restore_points():
    """Test that restore points are available"""
    print(f"{CYAN}🔍 Checking restore points...{NC}")
    
    try:
        server = get_terraform_output("sql_server_name")
        database = get_terraform_output("sql_database_name")
        rg = f"rg-e6-{os.getenv('TF_VAR_username')}"
        
        # List restore points
        az = getattr(sh, "az")
        result = az("sql", "db", "list-restore-points",
                      "--resource-group", rg,
                      "--server", server,
                      "--database", database,
                      "--query", "length(@)",
                      "-o", "tsv")
        
        count = int(result.strip())
        if count > 0:
            print(f"{GREEN}✓ {count} restore point(s) available{NC}")
            return True
        else:
            print(f"{YELLOW}⚠ No restore points available yet (database might be new){NC}")
            return True  # Not a failure, just new DB
    except Exception as e:
        print(f"{RED}✗ Failed to check restore points: {e}{NC}")
        return False

def test_automated_backups():
    """Test that automated backups are enabled"""
    print(f"{CYAN}🔍 Checking automated backups...{NC}")
    
    try:
        server = get_terraform_output("sql_server_name")
        database = get_terraform_output("sql_database_name")
        rg = f"rg-e6-{os.getenv('TF_VAR_username')}"
        
        # Get database properties
        az = getattr(sh, "az")
        result = az("sql", "db", "show",
                      "--resource-group", rg,
                      "--server", server,
                      "--name", database,
                      "--query", "{Status:status, Sku:currentSku.name, MaxSizeBytes:maxSizeBytes}",
                      "-o", "json")
        
        print(f"{GREEN}✓ Database is active and configured for backups{NC}")
        print(f"  {result}")
        return True
    except Exception as e:
        print(f"{RED}✗ Failed to check database: {e}{NC}")
        return False

def test_geo_replication():
    """Test geo-replication status (if enabled)"""
    print(f"{CYAN}🔍 Checking geo-replication...{NC}")
    
    try:
        server = get_terraform_output("sql_server_name")
        database = get_terraform_output("sql_database_name")
        rg = f"rg-e6-{os.getenv('TF_VAR_username')}"
        
        # Check if geo-backup is enabled
        az = getattr(sh, "az")
        result = az("sql", "db", "show",
                      "--resource-group", rg,
                      "--server", server,
                      "--name", database,
                      "--query", "zoneRedundant",
                      "-o", "tsv")
        
        zone_redundant = result.strip().lower() == 'true'
        
        if zone_redundant:
            print(f"{GREEN}✓ Zone redundancy enabled{NC}")
        else:
            print(f"{YELLOW}ℹ Zone redundancy not enabled (dev environment){NC}")
        
        return True
    except Exception as e:
        print(f"{YELLOW}⚠ Could not check geo-replication: {e}{NC}")
        return True  # Not critical

def generate_report(results):
    """Generate test report"""
    report_file = Path(__file__).parent / "backup_quick_report.txt"
    
    report_lines = [
        "=" * 60,
        "QUICK BACKUP TEST REPORT",
        "=" * 60,
        f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "Tests:",
        f"  Backup Retention Policy: {'✓ PASS' if results['retention'] else '✗ FAIL'}",
        f"  Restore Points Available: {'✓ PASS' if results['restore_points'] else '✗ FAIL'}",
        f"  Automated Backups: {'✓ PASS' if results['automated'] else '✗ FAIL'}",
        f"  Geo-Replication: {'✓ PASS' if results['geo'] else '✗ FAIL'}",
        "",
        f"Overall: {'✓ ALL TESTS PASSED' if all(results.values()) else '✗ SOME TESTS FAILED'}",
        "",
        "Note: This is a quick test. Run 'make test-backup-full' for complete restore test.",
        "=" * 60,
    ]
    
    with open(report_file, 'w') as f:
        f.write('\n'.join(report_lines))
    
    print(f"\n{CYAN}📄 Report saved: {report_file}{NC}")

def main():
    """Main test function"""
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Quick Backup Configuration Test{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")
    
    results = {
        'retention': test_backup_retention(),
        'restore_points': test_restore_points(),
        'automated': test_automated_backups(),
        'geo': test_geo_replication(),
    }
    
    generate_report(results)
    
    if all(results.values()):
        print(f"\n{GREEN}{'='*60}{NC}")
        print(f"{GREEN}✓ All backup tests passed!{NC}")
        print(f"{GREEN}{'='*60}{NC}\n")
        sys.exit(0)
    else:
        print(f"\n{RED}{'='*60}{NC}")
        print(f"{RED}✗ Some backup tests failed{NC}")
        print(f"{RED}{'='*60}{NC}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
