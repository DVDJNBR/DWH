import pyodbc
import os
from dotenv import load_dotenv

load_dotenv()

server = os.getenv("SQL_SERVER_FQDN")
database = os.getenv("SQL_DATABASE_NAME", "dwh-shopnow")
username = os.getenv("SQL_ADMIN_LOGIN", "dwhadmin")
password = os.getenv("SQL_ADMIN_PASSWORD")

print(f"Testing connection to {server}...")

connection_string = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={server};"
    f"DATABASE={database};"
    f"UID={username};"
    f"PWD={password};"
    f"Encrypt=yes;"
    f"TrustServerCertificate=yes;"
    f"LoginTimeout=10;"
)

try:
    conn = pyodbc.connect(connection_string)
    print("✅ Success!")
    conn.close()
except Exception as e:
    print(f"❌ Failed: {e}")
