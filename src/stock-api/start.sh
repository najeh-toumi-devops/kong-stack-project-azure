#!/bin/bash

echo "🚀 Démarrage de l'API Stocks..."

# Vérifier si on est dans le bon répertoire
if [ ! -f "requirements.txt" ]; then
    echo "❌ Veuillez exécuter ce script depuis le répertoire /opt/stock-api/"
    exit 1
fi

# Activer l'environnement virtuel
source venv/bin/activate

# Vérifier les variables d'environnement
if [ ! -f .env ]; then
    echo "⚠️  Fichier .env non trouvé, copie depuis .env.example"
    cp .env.example .env
fi

# Démarrer l'application
echo "🏃 Démarrage de Gunicorn..."
exec gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 --access-logfile - --error-logfile - run:app
