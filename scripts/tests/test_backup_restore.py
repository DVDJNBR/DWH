#!/usr/bin/env python3
"""
Script de test : Point-in-Time Restore
======================================

Ce script teste la fonctionnalité de backup et restauration Azure SQL Database

ÉTAPES :
1. Compte les données actuelles (état initial)
2. Note l'heure de référence
3. Supprime quelques données (simulation d'incident)
4. Compte les données après suppression
5. Restaure la base à l'heure de référence
6. Vérifie que les données sont récupérées
7. Génère un rapport complet

PRÉREQUIS :
- Azure CLI installé et connecté (az login)
- Python avec pyodbc et sh installés
- Base de données déployée avec backup activé
- Variables d'environnement dans .env

USAGE :
    uv run --directory scripts python test_backup_restore.py
"""

import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import pyodbc
import sh
from dotenv import load_dotenv

# Couleurs pour l'output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_header(text):
    """Affiche un header coloré"""
    print(f"\n{Colors.BLUE}{'━' * 60}{Colors.NC}")
    print(f"{Colors.BLUE}  {text}{Colors.NC}")
    print(f"{Colors.BLUE}{'━' * 60}{Colors.NC}\n")

def print_success(text):
    """Affiche un message de succès"""
    print(f"{Colors.GREEN}✓{Colors.NC} {text}")

def print_error(text):
    """Affiche un message d'erreur"""
    print(f"{Colors.RED}✗{Colors.NC} {text}")

def print_warning(text):
    """Affiche un avertissement"""
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.NC}")

def print_info(text):
    """Affiche une info"""
    print(f"{Colors.YELLOW}{text}{Colors.NC}")

def get_terraform_output(key):
    """Récupère une valeur depuis Terraform output"""
    try:
        # Le script est dans scripts/tests/, donc terraform est dans ../../terraform
        terraform_dir = Path(__file__).parent.parent.parent / "terraform"
        result = sh.terraform(f"-chdir={terraform_dir}", "output", "-raw", key)
        return result.strip()
    except sh.ErrorReturnCode as e:
        print_error(f"Erreur Terraform pour {key}: {e}")
        sys.exit(1)

def execute_sql(server, database, username, password, query):
    """Exécute une requête SQL et retourne le résultat"""
    connection_string = (
        f'DRIVER={{ODBC Driver 18 for SQL Server}};'
        f'SERVER={server};'
        f'DATABASE={database};'
        f'UID={username};'
        f'PWD={password};'
        f'Encrypt=yes;'
        f'TrustServerCertificate=no;'
        f'Connection Timeout=30;'
    )
    
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        cursor.execute(query)
        
        # Si c'est un SELECT, retourner le résultat
        if query.strip().upper().startswith('SELECT'):
            result = cursor.fetchone()
            value = result[0] if result else 0
        else:
            conn.commit()
            value = None
        
        cursor.close()
        conn.close()
        return value
    except Exception as e:
        print_error(f"Erreur SQL: {e}")
        raise

def main():
    """Fonction principale"""
    
    # =========================================================================
    # CONFIGURATION
    # =========================================================================
    
    print_header("TEST BACKUP & RESTORE - Azure SQL Database")
    
    # Charger les variables d'environnement
    env_path = Path(__file__).parent.parent.parent / '.env'
    if not env_path.exists():
        print_error("Fichier .env non trouvé")
        sys.exit(1)
    
    load_dotenv(env_path)
    
    sql_admin_login = os.getenv('SQL_ADMIN_LOGIN')
    sql_admin_password = os.getenv('SQL_ADMIN_PASSWORD')
    
    if not sql_admin_login or not sql_admin_password:
        print_error("Variables SQL_ADMIN_LOGIN ou SQL_ADMIN_PASSWORD manquantes dans .env")
        sys.exit(1)
    
    # Récupérer les infos Terraform
    print_info("📋 Récupération des informations Terraform...")
    rg_name = get_terraform_output('resource_group_name')
    sql_server_fqdn = get_terraform_output('sql_server_fqdn')
    sql_server_name = sql_server_fqdn.split('.')[0]
    db_name = get_terraform_output('sql_database_name')
    
    print_success(f"Resource Group    : {rg_name}")
    print_success(f"SQL Server        : {sql_server_name}")
    print_success(f"Database          : {db_name}")
    print()
    
    # Vérifier que la base existe
    print_info("🔍 Vérification de la base de données...")
    try:
        result = sh.az(
            "sql", "db", "show",
            "--resource-group", rg_name,
            "--server", sql_server_name,
            "--name", db_name,
            "--query", "status",
            "-o", "tsv"
        )
        db_status = result.strip()
        
        if db_status != "Online":
            print_error(f"Base de données non disponible (status: {db_status})")
            sys.exit(1)
        
        print_success("Base de données en ligne")
        print()
    except sh.ErrorReturnCode as e:
        print_error(f"Erreur lors de la vérification de la base: {e}")
        sys.exit(1)
    
    # =========================================================================
    # ÉTAPE 1 : ÉTAT INITIAL
    # =========================================================================
    
    print_header("ÉTAPE 1 : État initial")
    
    print_info("📊 Comptage des données actuelles...")
    
    orders_before = execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_order"
    )
    clicks_before = execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_clickstream"
    )
    
    print_success(f"fact_order       : {orders_before} lignes")
    print_success(f"fact_clickstream : {clicks_before} lignes")
    print()
    
    # =========================================================================
    # ÉTAPE 2 : POINT DE RÉFÉRENCE
    # =========================================================================
    
    print_header("ÉTAPE 2 : Point de référence")
    
    restore_time = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print_success(f"🕐 Heure de référence : {restore_time}")
    print()
    
    print_info("⏳ Attente de 2 minutes pour que le backup se fasse...")
    print_info("   (Azure fait des snapshots en continu)")
    
    for i in range(12):
        print(".", end="", flush=True)
        time.sleep(10)
    
    print()
    print_success("Attente terminée")
    print()
    
    # =========================================================================
    # ÉTAPE 3 : SIMULATION D'INCIDENT
    # =========================================================================
    
    print_header("ÉTAPE 3 : Simulation d'incident")
    
    print(f"{Colors.RED}💥 Suppression de données (simulation d'erreur)...{Colors.NC}")
    
    # Supprimer 10 commandes et 50 clics
    execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "DELETE TOP (10) FROM fact_order"
    )
    execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "DELETE TOP (50) FROM fact_clickstream"
    )
    
    # Compter après suppression
    orders_after = execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_order"
    )
    clicks_after = execute_sql(
        sql_server_fqdn, db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_clickstream"
    )
    
    orders_lost = orders_before - orders_after
    clicks_lost = clicks_before - clicks_after
    
    print(f"{Colors.RED}✓{Colors.NC} fact_order       : {orders_after} lignes ({Colors.RED}-{orders_lost}{Colors.NC})")
    print(f"{Colors.RED}✓{Colors.NC} fact_clickstream : {clicks_after} lignes ({Colors.RED}-{clicks_lost}{Colors.NC})")
    print()
    
    # =========================================================================
    # ÉTAPE 4 : RESTAURATION
    # =========================================================================
    
    print_header("ÉTAPE 4 : Restauration")
    
    restored_db_name = f"{db_name}-restored-{int(time.time())}"
    
    print_info(f"🔄 Restauration de la base à {restore_time}...")
    print_info(f"   Nom de la base restaurée : {restored_db_name}")
    print_info("   ⏳ Cela peut prendre 5-10 minutes...")
    print()
    
    start_time = time.time()
    
    try:
        sh.az(
            "sql", "db", "restore",
            "--resource-group", rg_name,
            "--server", sql_server_name,
            "--name", db_name,
            "--dest-name", restored_db_name,
            "--time", restore_time,
            "--output", "none"
        )
    except sh.ErrorReturnCode as e:
        print_error(f"Erreur lors de la restauration: {e}")
        sys.exit(1)
    
    duration = int(time.time() - start_time)
    
    print_success(f"Restauration terminée en {duration}s")
    print()
    
    # =========================================================================
    # ÉTAPE 5 : VÉRIFICATION
    # =========================================================================
    
    print_header("ÉTAPE 5 : Vérification")
    
    print_info("📊 Comptage des données dans la base restaurée...")
    print_info("⏳ Attente de 30 secondes pour que la base soit prête...")
    time.sleep(30)
    
    orders_restored = execute_sql(
        sql_server_fqdn, restored_db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_order"
    )
    clicks_restored = execute_sql(
        sql_server_fqdn, restored_db_name, sql_admin_login, sql_admin_password,
        "SELECT COUNT(*) FROM fact_clickstream"
    )
    
    print_success(f"fact_order       : {orders_restored} lignes")
    print_success(f"fact_clickstream : {clicks_restored} lignes")
    print()
    
    # =========================================================================
    # ÉTAPE 6 : RAPPORT FINAL
    # =========================================================================
    
    print_header("RAPPORT FINAL")
    
    # Générer le rapport
    report_file = f"backup_restore_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    
    success = (orders_restored == orders_before and clicks_restored == clicks_before)
    
    report = f"""{'━' * 60}
  RAPPORT DE TEST : BACKUP & RESTORE
{'━' * 60}

Date du test        : {datetime.now()}
Heure de référence  : {restore_time}
Durée de restauration : {duration}s

{'━' * 60}
  CONFIGURATION
{'━' * 60}

Resource Group      : {rg_name}
SQL Server          : {sql_server_name}
Base originale      : {db_name}
Base restaurée      : {restored_db_name}

{'━' * 60}
  RÉSULTATS
{'━' * 60}

Table : fact_order
  État initial      : {orders_before} lignes
  Après incident    : {orders_after} lignes (-{orders_lost})
  Après restauration: {orders_restored} lignes ({'+' if orders_restored - orders_before > 0 else ''}{orders_restored - orders_before if orders_restored != orders_before else '±0'})
  Récupération      : {'✓ SUCCÈS' if orders_restored == orders_before else '✗ ÉCHEC'}

Table : fact_clickstream
  État initial      : {clicks_before} lignes
  Après incident    : {clicks_after} lignes (-{clicks_lost})
  Après restauration: {clicks_restored} lignes ({'+' if clicks_restored - clicks_before > 0 else ''}{clicks_restored - clicks_before if clicks_restored != clicks_before else '±0'})
  Récupération      : {'✓ SUCCÈS' if clicks_restored == clicks_before else '✗ ÉCHEC'}

{'━' * 60}
  CONCLUSION
{'━' * 60}

"""
    
    if success:
        report += """✓ TEST RÉUSSI : Toutes les données ont été récupérées

Le Point-in-Time Restore fonctionne correctement.
Les données supprimées ont été entièrement récupérées.
"""
        print(f"{Colors.GREEN}✓ TEST RÉUSSI{Colors.NC}")
        print(f"{Colors.GREEN}  Toutes les données ont été récupérées !{Colors.NC}")
    else:
        report += f"""✗ TEST ÉCHOUÉ : Certaines données n'ont pas été récupérées

Différences détectées :
  - fact_order : attendu {orders_before}, obtenu {orders_restored}
  - fact_clickstream : attendu {clicks_before}, obtenu {clicks_restored}
"""
        print(f"{Colors.RED}✗ TEST ÉCHOUÉ{Colors.NC}")
        print(f"{Colors.RED}  Certaines données n'ont pas été récupérées{Colors.NC}")
    
    report += f"\n{'━' * 60}\n"
    
    # Sauvegarder le rapport
    with open(report_file, 'w') as f:
        f.write(report)
    
    print(report)
    print_success(f"📄 Rapport sauvegardé : {report_file}")
    print()
    
    # =========================================================================
    # ÉTAPE 7 : NETTOYAGE
    # =========================================================================
    
    print_header("NETTOYAGE")
    
    response = input("Voulez-vous supprimer la base restaurée ? (y/n) ")
    
    if response.lower() == 'y':
        print_info("🗑️  Suppression de la base restaurée...")
        try:
            sh.az(
                "sql", "db", "delete",
                "--resource-group", rg_name,
                "--server", sql_server_name,
                "--name", restored_db_name,
                "--yes",
                "--output", "none"
            )
            print_success("Base restaurée supprimée")
        except sh.ErrorReturnCode as e:
            print_error(f"Erreur lors de la suppression: {e}")
    else:
        print_warning(f"Base restaurée conservée : {restored_db_name}")
        print_warning("N'oublie pas de la supprimer plus tard pour éviter les coûts !")
    
    print()
    print(f"{Colors.GREEN}{'━' * 60}{Colors.NC}")
    print(f"{Colors.GREEN}  TEST TERMINÉ{Colors.NC}")
    print(f"{Colors.GREEN}{'━' * 60}{Colors.NC}")

if __name__ == "__main__":
    main()
