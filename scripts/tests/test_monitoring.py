#!/usr/bin/env python3
"""
Test Monitoring Configuration
===========================

Test that monitoring resources (Action Group, Alerts, Dashboard) are correctly deployed.

Usage:
    uv run --directory scripts python tests/test_monitoring.py
"""

import sys
import sh
from pathlib import Path

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
    try:
        result = terraform(f"-chdir={str(terraform_dir)}", "output", "-raw", key)
        return result.strip()
    except sh.ErrorReturnCode as e:
        print(f"{RED}✗ Failed to get Terraform output '{key}': {e}{NC}")
        return None

def check_resource_group(rg):
    """Check if resource group exists"""
    print(f"{CYAN}🔍 Checking Resource Group: {rg}...{NC}")
    az = getattr(sh, "az")
    try:
        az("group", "show", "--name", rg)
        print(f"{GREEN}✓ Resource Group found{NC}")
        return True
    except sh.ErrorReturnCode:
        print(f"{RED}✗ Resource Group not found{NC}")
        return False

def check_action_group(rg):
    """Check if Action Group exists"""
    print(f"{CYAN}🔍 Checking Action Group...{NC}")
    az = getattr(sh, "az")
    try:
        result = az("monitor", "action-group", "list", "--resource-group", rg, "--query", "[].name", "-o", "tsv")
        names = result.strip().split('\n') if result.strip() else []
        
        if names:
            print(f"{GREEN}✓ Found Action Group(s): {', '.join(names)}{NC}")
            return True
        else:
            print(f"{RED}✗ No Action Group found in {rg}{NC}")
            return False
    except sh.ErrorReturnCode as e:
        print(f"{RED}✗ Failed to list Action Groups: {e}{NC}")
        return False

def check_metric_alerts(rg):
    """Check if Metric Alerts exist"""
    print(f"{CYAN}🔍 Checking Metric Alerts...{NC}")
    az = getattr(sh, "az")
    try:
        result = az("monitor", "metrics", "alert", "list", "--resource-group", rg, "--query", "[].name", "-o", "tsv")
        names = result.strip().split('\n') if result.strip() else []
        
        if names:
            print(f"{GREEN}✓ Found Metric Alert(s): {', '.join(names)}{NC}")
            return True
        else:
            print(f"{RED}✗ No Metric Alerts found in {rg}{NC}")
            return False
    except sh.ErrorReturnCode as e:
         print(f"{RED}✗ Failed to list Metric Alerts: {e}{NC}")
         return False

def check_activity_log_alerts(rg):
    """Check if Activity Log Alerts exist"""
    print(f"{CYAN}🔍 Checking Activity Log Alerts...{NC}")
    az = getattr(sh, "az")
    try:
        result = az("monitor", "activity-log", "alert", "list", "--resource-group", rg, "--query", "[].name", "-o", "tsv")
        names = result.strip().split('\n') if result.strip() else []
        
        if names:
             print(f"{GREEN}✓ Found Activity Log Alert(s): {', '.join(names)}{NC}")
             return True
        else:
             print(f"{RED}✗ No Activity Log Alerts found in {rg}{NC}")
             return False
    except sh.ErrorReturnCode as e:
        print(f"{RED}✗ Failed to list Activity Log Alerts: {e}{NC}")
        return False

def check_dashboard(rg):
    """Check if Dashboard exists"""
    print(f"{CYAN}🔍 Checking Azure Dashboard...{NC}")
    az = getattr(sh, "az")
    try:
        result = az("portal", "dashboard", "list", "--resource-group", rg, "--query", "[].name", "-o", "tsv")
        names = result.strip().split('\n') if result.strip() else []
        
        if names:
             print(f"{GREEN}✓ Found Dashboard(s): {', '.join(names)}{NC}")
             return True
        else:
             # Dashboards might be in a different RG or hidden, but Terraform usually puts them in the main RG
             # Let's try listing all relevant dashboards for this project
             print(f"{YELLOW}⚠ No dashboard found explicitly in {rg}, checking all...{NC}")
             az = getattr(sh, "az")
             result = az("portal", "dashboard", "list", "--query", "[?contains(name, 'dwh')].name", "-o", "tsv")
             names = result.strip().split('\n') if result.strip() else []
             if names:
                 print(f"{GREEN}✓ Found Dashboard(s) matching 'dwh': {', '.join(names)}{NC}")
                 return True
             
             print(f"{RED}✗ No Dashboard found{NC}")
             return False
    except sh.ErrorReturnCode as e:
        print(f"{RED}✗ Failed to list Dashboards: {e}{NC}")
        return False


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
    report_path = Path(__file__).parent / 'monitoring_report.txt'
    output_buffer = OutputBuffer(str(report_path))
    sys.stdout = output_buffer
    
    print(f"\n{CYAN}{'='*60}{NC}")
    print(f"{CYAN}Test: Operations Monitoring Configuration{NC}")
    print(f"{CYAN}{'='*60}{NC}\n")

    try:
        rg = get_terraform_output("resource_group_name")
        if not rg:
            print(f"{RED}✗ Could not retrieve resource group name from Terraform output.{NC}")
            sys.exit(1)

        checks = [
            check_resource_group(rg),
            check_action_group(rg),
            check_metric_alerts(rg),
            check_activity_log_alerts(rg),
            check_dashboard(rg)
        ]

        print(f"\n{CYAN}{'='*60}{NC}")
        if all(checks):
            print(f"{GREEN}✓ All monitoring tests passed!{NC}")
            print(f"{GREEN}{'='*60}{NC}")
            print(f"\n📄 Report saved: {report_path}\n")
            sys.exit(0)
        else:
            print(f"{RED}✗ Some monitoring tests failed.{NC}")
            print(f"{YELLOW}💡 Ensure you have run 'make enable-monitoring'{NC}")
            print(f"{RED}{'='*60}{NC}\n")
            sys.exit(1)

    finally:
        output_buffer.save()
        sys.stdout = output_buffer.original_stdout

if __name__ == "__main__":
    main()

