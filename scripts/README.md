# 📊 Scripts utilitaires

## seed_historical_data.py

Script pour générer des données historiques dans le Data Warehouse afin de rendre les analyses plus réalistes.

### 🎯 Pourquoi ?

Quand tu déploies l'infrastructure, le DWH est vide. Les producers génèrent des données en temps réel, mais tu n'as pas d'historique pour faire des analyses de tendances, des comparaisons mensuelles, etc.

Ce script insère des données fictives pour les 30 derniers jours (configurable).

### 📦 Installation

```bash
# Avec uv (recommandé)
# Les dépendances sont gérées automatiquement via pyproject.toml

# Sur Linux, installer le driver ODBC
sudo apt-get install unixodbc-dev
```

### 🚀 Utilisation

#### Méthode 1 : Avec les outputs Terraform

```bash
# Récupérer les infos depuis Terraform
cd terraform
SERVER=$(terraform output -raw sql_server_fqdn)
DATABASE=$(terraform output -raw sql_database_name)

# Lancer le script
cd ..
python scripts/seed_historical_data.py \
    --server $SERVER \
    --database $DATABASE \
    --username dwhadmin \
    --password YourPassword123!
```

#### Méthode 2 : Manuellement

```bash
# Avec uv (recommandé)
uv run --directory scripts seed_historical_data.py \
    --server sql-dbreau-whole-rat.database.windows.net \
    --database dwh-shopnow \
    --username dwhadmin \
    --password YourPassword123!

# Ou avec python classique
cd scripts
pip install -e .
python seed_historical_data.py \
    --server sql-dbreau-whole-rat.database.windows.net \
    --database dwh-shopnow \
    --username dwhadmin \
    --password YourPassword123!
```

#### Options avancées

```bash
# Générer 60 jours d'historique
python scripts/seed_historical_data.py \
    --server $SERVER \
    --database $DATABASE \
    --username dwhadmin \
    --password YourPassword123! \
    --days 60

# Plus de commandes par jour
python scripts/seed_historical_data.py \
    --server $SERVER \
    --database $DATABASE \
    --username dwhadmin \
    --password YourPassword123! \
    --days 30 \
    --orders-per-day 100 \
    --clicks-per-day 1000
```

### 📊 Ce qui est généré

**Par défaut (30 jours)** :

- **100 clients** dans `dim_customer`
- **100 produits** dans `dim_product`
- **1,500 commandes** dans `fact_order` (50/jour × 30 jours)
- **15,000 événements** dans `fact_clickstream` (500/jour × 30 jours)

**Données réalistes** :

- Noms, emails, adresses générés avec Faker
- Timestamps répartis sur les 30 derniers jours
- Variation des heures (0-23h)
- Mix de statuts (completed, pending, cancelled)
- Mix de types d'événements (view_page, add_to_cart, checkout_start)

### 🔍 Vérification

Après l'exécution, le script affiche les statistiques :

```
📊 Statistiques du Data Warehouse:
============================================================
  Clients...................................... 100
  Produits..................................... 100
  Commandes (lignes)........................... 3,750
  Événements clickstream....................... 15,000

📅 Période des commandes:
  Première commande: 2025-10-25 08:23:15
  Dernière commande: 2025-11-24 22:45:32

📅 Période des événements:
  Premier événement: 2025-10-25 00:12:45
  Dernier événement: 2025-11-24 23:58:12
============================================================
```

### 🎨 Analyses possibles après seeding

Avec des données historiques, tu peux faire des analyses réalistes :

```sql
-- Évolution des ventes par jour
SELECT 
    CAST(order_timestamp AS DATE) as order_date,
    COUNT(DISTINCT order_id) as orders,
    SUM(quantity * unit_price) as revenue
FROM fact_order
WHERE status = 'completed'
GROUP BY CAST(order_timestamp AS DATE)
ORDER BY order_date;

-- Top produits du mois
SELECT 
    p.name,
    p.category,
    COUNT(*) as times_ordered,
    SUM(f.quantity) as total_quantity,
    SUM(f.quantity * f.unit_price) as revenue
FROM fact_order f
JOIN dim_product p ON f.product_id = p.product_id
WHERE f.order_timestamp >= DATEADD(day, -30, GETDATE())
GROUP BY p.name, p.category
ORDER BY revenue DESC;

-- Taux de conversion (clickstream → orders)
WITH daily_stats AS (
    SELECT 
        CAST(event_timestamp AS DATE) as date,
        COUNT(CASE WHEN event_type = 'view_page' THEN 1 END) as views,
        COUNT(CASE WHEN event_type = 'add_to_cart' THEN 1 END) as add_to_carts,
        COUNT(CASE WHEN event_type = 'checkout_start' THEN 1 END) as checkouts
    FROM fact_clickstream
    GROUP BY CAST(event_timestamp AS DATE)
)
SELECT 
    date,
    views,
    add_to_carts,
    checkouts,
    CAST(add_to_carts AS FLOAT) / NULLIF(views, 0) * 100 as cart_rate,
    CAST(checkouts AS FLOAT) / NULLIF(add_to_carts, 0) * 100 as checkout_rate
FROM daily_stats
ORDER BY date;
```

### ⚠️ Notes importantes

1. **Idempotence** : Le script vérifie si les clients/produits existent déjà avant insertion
2. **Performance** : Utilise des commits par batch (100 commandes, 500 clics)
3. **Connexion** : Nécessite que le firewall SQL autorise ton IP
4. **Temps d'exécution** : ~2-3 minutes pour 30 jours de données

### 🔄 Réinitialisation

Si tu veux repartir de zéro :

```sql
-- Vider toutes les tables
TRUNCATE TABLE fact_order;
TRUNCATE TABLE fact_clickstream;
DELETE FROM dim_customer;
DELETE FROM dim_product;
```

Puis relance le script de seeding.

### 🚀 Intégration avec Terraform

Tu peux automatiser le seeding après le déploiement en ajoutant un container qui exécute ce script :

```hcl
resource "azurerm_container_group" "data_seeder" {
  name                = "data-seeder"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  restart_policy      = "Never"  # Une seule exécution
  
  container {
    name   = "seeder"
    image  = "python:3.12-slim"
    cpu    = 0.5
    memory = 1
    
    commands = [
      "/bin/bash",
      "-c",
      "pip install pyodbc Faker && python seed_historical_data.py ..."
    ]
  }
}
```

### 📚 Ressources

- [pyodbc documentation](https://github.com/mkleehammer/pyodbc/wiki)
- [Faker documentation](https://faker.readthedocs.io/)
