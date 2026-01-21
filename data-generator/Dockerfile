# Dockerfile pour data-generator
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for pyodbc (using modern GPG key method)
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    unixodbc-dev \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installer uv et supervisor
RUN pip install --no-cache-dir uv supervisor

# Copier les fichiers de dépendances
COPY pyproject.toml .

# Installer les dépendances avec uv
RUN uv pip install --system --no-cache azure-eventhub faker pyodbc

# Copier le code
COPY producers.py .
COPY producers_marketplace.py .
COPY supervisord.conf .

# Lancer supervisord pour gérer les deux producers
CMD ["supervisord", "-c", "supervisord.conf"]
