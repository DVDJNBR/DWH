# Dockerfile pour data-generator
FROM python:3.11-slim

WORKDIR /app

# Installer uv
RUN pip install --no-cache-dir uv

# Copier les fichiers de dépendances
COPY pyproject.toml .

# Installer les dépendances avec uv (sans builder le package)
RUN uv pip install --system --no-cache azure-eventhub faker

# Copier le code
COPY producers.py .

# Lancer le script
CMD ["python", "producers.py"]
