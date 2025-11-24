# 🎲 Data Generator

Synthetic event generator for Azure Data Warehouse project.

## 🎯 What it does

Generates fake e-commerce events:
- 📦 **Orders** : 1 event/minute (customers, products, prices)
- 🖱️ **Clickstream** : 30 events/minute (page views, cart actions, checkouts)

## 🚀 Build & Push

```bash
# Build the image
docker build -t VOTRE_USERNAME/data-generator:latest .

# Push to Docker Hub
docker push VOTRE_USERNAME/data-generator:latest
```

## 🧪 Test locally

```bash
docker run --rm \
  -e EVENTHUB_CONNECTION_STR="Endpoint=sb://..." \
  -e ORDERS_INTERVAL=10 \
  -e CLICKSTREAM_INTERVAL=2 \
  VOTRE_USERNAME/data-generator:latest
```

## ⚙️ Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `EVENTHUB_CONNECTION_STR` | - | Event Hub connection string (required) |
| `ORDERS_INTERVAL` | 60 | Interval between orders (seconds) |
| `CLICKSTREAM_INTERVAL` | 2 | Interval between clickstream events (seconds) |

## 📊 Generated data

- 100 fake customers (Faker)
- 1000 fake products (Faker)
- Realistic events with coherent relationships
