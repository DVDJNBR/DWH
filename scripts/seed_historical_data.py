#!/usr/bin/env python3
"""
Script pour générer des données historiques dans le Data Warehouse.

Ce script insère des données fictives pour les 30 derniers jours afin de
rendre les analyses plus réalistes lors des tests.

Usage:
    python scripts/seed_historical_data.py \
        --server sql-dbreau-whole-rat.database.windows.net \
        --database dwh-shopnow \
        --username dwhadmin \
        --password YourPassword123!
"""

import pyodbc
import random
import uuid
import os
from datetime import datetime, timedelta
from faker import Faker
from dotenv import load_dotenv
import argparse

# Charger les variables d'environnement depuis .env
load_dotenv()

fake = Faker()

# Configuration
DAYS_OF_HISTORY = 30
ORDERS_PER_DAY = 50
CLICKS_PER_DAY = 500

# Pools de données
CUSTOMERS_POOL = []
PRODUCTS_POOL = []

def create_connection(server, database, username, password):
    """Crée une connexion à SQL Server."""
    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(connection_string)

def generate_customers(count=100):
    """Génère un pool de clients fictifs."""
    print(f"📝 Génération de {count} clients...")
    customers = []
    for _ in range(count):
        customers.append({
            "customer_id": str(uuid.uuid4()),
            "name": fake.name(),
            "email": fake.email(),
            "address": fake.street_address(),
            "city": fake.city(),
            "country": fake.country()
        })
    return customers

def generate_products(count=100):
    """Génère un pool de produits fictifs."""
    print(f"📦 Génération de {count} produits...")
    products = []
    categories = ["Electronics", "Home", "Clothing", "Books", "Beauty", "Sports", "Toys"]
    
    for _ in range(count):
        products.append({
            "product_id": str(uuid.uuid4()),
            "name": fake.catch_phrase(),
            "category": random.choice(categories)
        })
    return products

def insert_customers(conn, customers):
    """Insère les clients dans dim_customer."""
    print(f"👥 Insertion de {len(customers)} clients dans dim_customer...")
    cursor = conn.cursor()
    
    for customer in customers:
        cursor.execute("""
            IF NOT EXISTS (SELECT 1 FROM dim_customer WHERE customer_id = ?)
            INSERT INTO dim_customer (customer_id, name, email, address, city, country)
            VALUES (?, ?, ?, ?, ?, ?)
        """, 
        customer["customer_id"],
        customer["customer_id"],
        customer["name"],
        customer["email"],
        customer["address"],
        customer["city"],
        customer["country"])
    
    conn.commit()
    print("✅ Clients insérés")

def insert_products(conn, products):
    """Insère les produits dans stg_product."""
    print(f"📦 Insertion de {len(products)} produits dans stg_product...")
    cursor = conn.cursor()
    
    for product in products:
        event_timestamp = datetime.now() # Add event_timestamp for SCD2
        cursor.execute("""
            INSERT INTO stg_product (product_id, name, category, event_timestamp)
            VALUES (?, ?, ?, ?)
        """,
        product["product_id"],
        product["name"],
        product["category"],
        event_timestamp)
    
    conn.commit()
    print("✅ Produits insérés dans stg_product")

def generate_historical_orders(conn, customers, products, days, orders_per_day):
    """Génère des commandes historiques."""
    print(f"🛒 Génération de {days * orders_per_day} commandes historiques...")
    cursor = conn.cursor()
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    total_orders = 0
    for day in range(days):
        current_date = start_date + timedelta(days=day)
        
        for _ in range(orders_per_day):
            # Sélectionner un client et des produits aléatoires
            customer = random.choice(customers)
            num_items = random.randint(1, 5)
            selected_products = random.sample(products, num_items)
            
            order_id = str(uuid.uuid4())
            
            # Ajouter un peu de variation dans l'heure
            order_time = current_date + timedelta(
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59),
                seconds=random.randint(0, 59)
            )
            
            # Insérer chaque item de la commande
            for product in selected_products:
                quantity = random.randint(1, 3)
                unit_price = round(random.uniform(10, 500), 2)
                status = random.choice(["completed", "completed", "completed", "pending", "cancelled"])
                
                cursor.execute("""
                    INSERT INTO fact_order 
                    (order_id, product_id, customer_id, quantity, unit_price, status, order_timestamp)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                order_id,
                product["product_id"],
                customer["customer_id"],
                quantity,
                unit_price,
                status,
                order_time)
            
            total_orders += 1
            
            # Commit par batch de 100 commandes
            if total_orders % 100 == 0:
                conn.commit()
                print(f"  ✓ {total_orders} commandes insérées...")
    
    conn.commit()
    print(f"✅ {total_orders} commandes historiques insérées")

def generate_historical_clickstream(conn, days, clicks_per_day):
    """Génère des événements clickstream historiques."""
    print(f"🖱️  Génération de {days * clicks_per_day} événements clickstream...")
    cursor = conn.cursor()
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    event_types = ["view_page", "view_page", "view_page", "add_to_cart", "checkout_start"]
    urls = [
        "/",
        "/products",
        "/category/electronics",
        "/category/home",
        "/category/clothing",
        "/cart",
        "/checkout",
        "/product/123",
        "/product/456"
    ]
    
    total_events = 0
    for day in range(days):
        current_date = start_date + timedelta(days=day)
        
        for _ in range(clicks_per_day):
            event_time = current_date + timedelta(
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59),
                seconds=random.randint(0, 59)
            )
            
            event_type = random.choice(event_types)
            url = random.choice(urls)
            
            # Ajuster l'URL selon le type d'événement
            if event_type == "add_to_cart":
                url = "/cart"
            elif event_type == "checkout_start":
                url = "/checkout"
            
            cursor.execute("""
                INSERT INTO fact_clickstream 
                (event_id, session_id, user_id, url, event_type, event_timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            """,
            str(uuid.uuid4()),
            str(uuid.uuid4()),
            str(uuid.uuid4()) if random.random() > 0.3 else None,
            url,
            event_type,
            event_time)
            
            total_events += 1
            
            # Commit par batch de 500 événements
            if total_events % 500 == 0:
                conn.commit()
                print(f"  ✓ {total_events} événements insérés...")
    
    conn.commit()
    print(f"✅ {total_events} événements clickstream insérés")

def show_statistics(conn):
    """Affiche les statistiques des données insérées."""
    print("\n📊 Statistiques du Data Warehouse:")
    print("=" * 60)
    
    cursor = conn.cursor()
    
    # Compter les lignes par table
    tables = [
        ("dim_customer", "Clients"),
        ("dim_product", "Produits"),
        ("fact_order", "Commandes (lignes)"),
        ("fact_clickstream", "Événements clickstream")
    ]
    
    for table, label in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"  {label:.<40} {count:>10,}")
    
    # Période couverte
    cursor.execute("""
        SELECT 
            MIN(order_timestamp) as first_order,
            MAX(order_timestamp) as last_order
        FROM fact_order
    """)
    row = cursor.fetchone()
    if row and row[0]:
        print(f"\n📅 Période des commandes:")
        print(f"  Première commande: {row[0]}")
        print(f"  Dernière commande: {row[1]}")
    
    cursor.execute("""
        SELECT 
            MIN(event_timestamp) as first_event,
            MAX(event_timestamp) as last_event
        FROM fact_clickstream
    """)
    row = cursor.fetchone()
    if row and row[0]:
        print(f"\n📅 Période des événements:")
        print(f"  Premier événement: {row[0]}")
        print(f"  Dernier événement: {row[1]}")
    
    print("=" * 60)

def main():
    parser = argparse.ArgumentParser(description="Génère des données historiques pour le DWH")
    parser.add_argument("--server", help="SQL Server FQDN")
    parser.add_argument("--database", help="Nom de la base de données")
    parser.add_argument("--username", help="Username SQL")
    parser.add_argument("--password", help="Password SQL")
    parser.add_argument("--days", type=int, default=DAYS_OF_HISTORY, help="Nombre de jours d'historique")
    parser.add_argument("--orders-per-day", type=int, default=ORDERS_PER_DAY, help="Commandes par jour")
    parser.add_argument("--clicks-per-day", type=int, default=CLICKS_PER_DAY, help="Clics par jour")
    
    args = parser.parse_args()
    
    # Utiliser les variables d'environnement si les arguments ne sont pas fournis
    server = args.server or os.getenv("SQL_SERVER_FQDN")
    database = args.database or os.getenv("SQL_DATABASE_NAME", "dwh-shopnow")
    username = args.username or os.getenv("SQL_ADMIN_LOGIN", "dwhadmin")
    password = args.password or os.getenv("SQL_ADMIN_PASSWORD")
    
    if not all([server, database, username, password]):
        print("❌ Erreur: Informations de connexion manquantes")
        print("Fournissez-les via arguments ou fichier .env")
        print("\nExemple .env:")
        print("SQL_SERVER_FQDN=sql-xxx.database.windows.net")
        print("SQL_DATABASE_NAME=dwh-shopnow")
        print("SQL_ADMIN_LOGIN=dwhadmin")
        print("SQL_ADMIN_PASSWORD=YourPassword123!")
        exit(1)
    
    print("🚀 Génération de données historiques pour le Data Warehouse")
    print("=" * 60)
    print(f"Serveur: {server}")
    print(f"Base de données: {database}")
    print(f"Période: {args.days} jours")
    print(f"Commandes/jour: {args.orders_per_day}")
    print(f"Clics/jour: {args.clicks_per_day}")
    print("=" * 60)
    
    # Connexion
    print("\n🔌 Connexion à la base de données...")
    conn = create_connection(server, database, username, password)
    print("✅ Connecté")
    
    # Générer les pools
    global CUSTOMERS_POOL, PRODUCTS_POOL
    CUSTOMERS_POOL = generate_customers(100)
    PRODUCTS_POOL = generate_products(100)
    
    # Insérer les dimensions
    insert_customers(conn, CUSTOMERS_POOL)
    insert_products(conn, PRODUCTS_POOL)
    
    # Générer les faits historiques
    generate_historical_orders(conn, CUSTOMERS_POOL, PRODUCTS_POOL, args.days, args.orders_per_day)
    generate_historical_clickstream(conn, args.days, args.clicks_per_day)
    
    # Afficher les stats
    show_statistics(conn)
    
    conn.close()
    print("\n✅ Terminé!")

if __name__ == "__main__":
    main()
