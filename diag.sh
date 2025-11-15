#!/bin/bash

echo "🔍 DIAGNOSTIC COMPLET DE L'API STOCKS"

# 1. Vérification des services
echo ""
echo "1. 📊 STATUT DES SERVICES"
sudo systemctl status stock-api --no-pager --lines=5
sudo systemctl status mongod --no-pager --lines=3
sudo systemctl status redis-server --no-pager --lines=3

# 2. Vérification des ports
echo ""
echo "2. 🔌 PORTS ÉCOUTÉS"
sudo netstat -tlnp | grep -E "(8000|27017|6379)"

# 3. Vérification des fichiers critiques
echo ""
echo "3. 📁 FICHIERS CRITIQUES"
ls -la /opt/stock-api/run.py
ls -la /opt/stock-api/app/__init__.py
ls -la /opt/stock-api/config/config.py

# 4. Vérification de l'environnement Python
echo ""
echo "4. 🐍 ENVIRONNEMENT PYTHON"
ls -la /opt/stock-api/venv/bin/python
/opt/stock-api/venv/bin/python --version

# 5. Test manuel de l'application
echo ""
echo "5. 🧪 TEST MANUEL"
cd /opt/stock-api
sudo -u stockapi bash -c "source venv/bin/activate && python -c 'from app import create_app; app = create_app(); print(\"✅ Application importée avec succès\")'" || echo "❌ Erreur d'import"

# 6. Test direct avec Gunicorn
echo ""
echo "6. 🚀 TEST GUNICORN"
timeout 5 sudo -u stockapi bash -c "cd /opt/stock-api && source venv/bin/activate && gunicorn --bind 0.0.0.0:8000 --workers 1 --timeout 30 run:app" &
sleep 3
curl -s http://localhost:8000/api/v1/health && echo "✅ API accessible" || echo "❌ API inaccessible"
pkill gunicorn

echo ""
echo "🔍 DIAGNOSTIC TERMINÉ"
