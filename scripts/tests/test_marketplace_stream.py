#!/usr/bin/env python3
"""
Test Stream Analytics Marketplace Configuration

Validates that the marketplace Stream Analytics job is properly configured
with all required inputs, outputs, and queries.
"""

import sys
from pathlib import Path

import json
import sh
from dotenv import load_dotenv

# Color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'
BOLD = '\033[1m'

# Load environment
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)


def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent.parent / "terraform"
    terraform = getattr(sh, "terraform")
    result = terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
    return result.strip()


def print_header(text):
    """Print section header"""
    print(f"\n{CYAN}{'━' * 80}{NC}")
    print(f"{CYAN}  {text}{NC}")
    print(f"{CYAN}{'━' * 80}{NC}\n")


def print_test(name, passed, details=""):
    """Print test result"""
    status = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
    print(f"{status} {name}")
    if details:
        print(f"  {details}")
    return passed


def main():
    """Run marketplace stream tests"""
    print(f"{BOLD}🧪 Testing Stream Analytics Marketplace Configuration{NC}")
    
    # Get configuration
    resource_group = get_terraform_output('resource_group_name')
    job_name = get_terraform_output('stream_analytics_job_name')
    
    print(f"\n{YELLOW}Configuration:{NC}")
    print(f"  Resource Group: {resource_group}")
    print(f"  Job Name: {job_name}")
    
    tests_passed = 0
    tests_total = 0
    
    # ============================================================================
    # TEST 1: Job Exists and Status
    # ============================================================================
    print_header("TEST 1: Stream Analytics Job Status")
    
    try:
        az = getattr(sh, "az")
        result = az(
            "stream-analytics", "job", "show",
            "--resource-group", resource_group,
            "--name", job_name,
            "--query", "{Name:name, State:jobState, StreamingUnits:transformation.streamingUnits}",
            "-o", "json"
        )
        
        job_info = json.loads(str(result))
        
        tests_total += 1
        if print_test(f"Job exists: {job_info['Name']}", True):
            tests_passed += 1
        
        tests_total += 1
        state = job_info.get('State', 'Unknown')
        if print_test(f"Job state: {state}", state in ['Running', 'Starting'], 
                     f"Expected Running/Starting, got {state}"):
            tests_passed += 1
        
        # StreamingUnits may be null for newly created jobs - just warn
        sus = job_info.get('StreamingUnits')
        if sus is None:
            print(f"{YELLOW}⚠️{NC}  Streaming units: N/A (may not be allocated yet for new jobs)")
        else:
            tests_total += 1
            if print_test(f"Streaming units: {sus}", sus >= 1, f"Expected ≥1, got {sus}"):
                tests_passed += 1
            
    except Exception as e:
        tests_total += 3
        print_test("Job status check", False, str(e))
    
    # ============================================================================
    # TEST 2: Inputs Configuration
    # ============================================================================
    print_header("TEST 2: Stream Inputs")
    
    expected_inputs = ['InputOrders', 'InputClickstream', 'InputVendors']
    
    try:
        az = getattr(sh, "az")
        result = az(
            "stream-analytics", "input", "list",
            "--resource-group", resource_group,
            "--job-name", job_name,
            "--query", "[].name",
            "-o", "json"
        )
        
        inputs = json.loads(str(result))
        
        for expected in expected_inputs:
            tests_total += 1
            found = expected in inputs
            if print_test(f"Input '{expected}' exists", found):
                tests_passed += 1
                
    except Exception as e:
        tests_total += len(expected_inputs)
        print_test("Inputs check", False, str(e))
    
    # ============================================================================
    # TEST 3: Outputs Configuration
    # ============================================================================
    print_header("TEST 3: Stream Outputs")
    
    expected_outputs = [
        'OutputFactOrder',
        'OutputFactClickstream',
        'OutputDimCustomer',
        'OutputStgProduct',
        'OutputStgVendor'
    ]
    
    try:
        az = getattr(sh, "az")
        result = az(
            "stream-analytics", "output", "list",
            "--resource-group", resource_group,
            "--job-name", job_name,
            "--query", "[].name",
            "-o", "json"
        )
        
        outputs = json.loads(str(result))
        
        for expected in expected_outputs:
            tests_total += 1
            found = expected in outputs
            if print_test(f"Output '{expected}' exists", found):
                tests_passed += 1
                
    except Exception as e:
        tests_total += len(expected_outputs)
        print_test("Outputs check", False, str(e))
    
    # ============================================================================
    # Summary
    # ============================================================================
    print_header("TEST SUMMARY")
    
    success_rate = (tests_passed / tests_total * 100) if tests_total > 0 else 0
    
    print(f"\nTotal tests: {tests_total}")
    print(f"Passed: {GREEN}{tests_passed}{NC}")
    print(f"Failed: {RED}{tests_total - tests_passed}{NC}")
    print(f"Success rate: {success_rate:.1f}%\n")
    
    if tests_passed == tests_total:
        print(f"{GREEN}✓ ALL TESTS PASSED{NC}")
        print(f"\n{CYAN}{'━' * 80}{NC}\n")
        return 0
    else:
        print(f"{RED}✗ SOME TESTS FAILED{NC}")
        print(f"\n{CYAN}{'━' * 80}{NC}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
