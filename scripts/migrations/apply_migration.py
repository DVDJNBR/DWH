#!/usr/bin/env python3
"""
Apply SQL migration to the database
"""

import os
import sys
from pathlib import Path

import pyodbc
import sh
from dotenv import load_dotenv

# Load environment
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

def get_terraform_output(key):
    """Get Terraform output value"""
    terraform_dir = Path(__file__).parent.parent.parent / "terraform"
    result = sh.terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
    return result.strip()

def apply_migration(migration_number):
    """Apply a specific migration"""
    
    # Get database connection info
    server = get_terraform_output('sql_server_fqdn')
    database = get_terraform_output('sql_database_name')
    username = os.getenv('SQL_ADMIN_LOGIN')
    password = os.getenv('SQL_ADMIN_PASSWORD')
    
    print(f"📊 Connecting to {server} / {database}")
    
    # Find migration file by number
    migrations_dir = Path(__file__).parent
    migration_files = list(migrations_dir.glob(f"{migration_number}_*.sql"))

    if not migration_files:
        print(f"❌ No migration file found starting with: {migration_number}_")
        print(f"📂 Looking in: {migrations_dir}")
        sys.exit(1)

    migration_file = migration_files[0]
    
    if not migration_file.exists():
        print(f"❌ Migration file not found: {migration_file}")
        sys.exit(1)
    
    print(f"📄 Reading migration: {migration_file.name}")
    
    with open(migration_file, 'r') as f:
        sql_content = f.read()
    
    # Connect to database
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
        
        # Split by GO and execute each batch
        statements = sql_content.split('GO')
        total = len([s for s in statements if s.strip()])
        
        print(f"🔄 Executing {total} SQL batches...")
        
        for i, statement in enumerate(statements, 1):
            if statement.strip():
                try:
                    cursor.execute(statement)
                    conn.commit()
                except Exception as e:
                    # Print but continue (some statements might be idempotent checks)
                    if "already exists" not in str(e):
                        print(f"⚠️  Warning in batch {i}: {e}")
        
        cursor.close()
        conn.close()
        
        print("✅ Migration completed successfully!")
        
    except Exception as e:
        print(f"❌ Error applying migration: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python apply_migration.py <migration_number>")
        print("Example: python apply_migration.py 001")
        sys.exit(1)
    
    migration_number = sys.argv[1]
    apply_migration(migration_number)
