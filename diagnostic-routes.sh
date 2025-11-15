#!/bin/bash

echo "🔍 DIAGNOSTIC DES ROUTES API"

APP_DIR="/opt/stock-api"

# 1. Vérifier la structure des fichiers
echo ""
echo "1. 📁 STRUCTURE DES FICHIERS"
ls -la $APP_DIR/app/routes/
ls -la $APP_DIR/app/__init__.py

# 2. Vérifier le contenu de app/__init__.py
echo ""
echo "2. 📝 CONTENU de app/__init__.py"
sudo grep -A 10 -B 5 "stocks_bp" $APP_DIR/app/__init__.py || echo "❌ Route non trouvée"

# 3. Vérifier le fichier de routes
echo ""
echo "3. 🛣️ FICHIER DE ROUTES"
ls -la $APP_DIR/app/routes/stocks.py
sudo head -20 $APP_DIR/app/routes/stocks.py

# 4. Test des imports Python
echo ""
echo "4. 🐍 TEST DES IMPORTS"
cd $APP_DIR
sudo -u stockapi bash -c "source venv/bin/activate && python -c '
try:
    from app.routes.stocks import stocks_bp
    print(\"✅ Import stocks_bp: OK\")
except Exception as e:
    print(f\"❌ Import stocks_bp: {e}\")

try:
    from app import create_app
    app = create_app()
    print(\"✅ Create app: OK\")
    print(\"Routes enregistrées:\", [str(rule) for rule in app.url_map.iter_rules()][:10])
except Exception as e:
    print(f\"❌ Create app: {e}\")
'"

# 5. Vérifier les logs
echo ""
echo "5. 📋 LOGS RÉCENTS"
sudo journalctl -u stock-api -n 10 --no-pager
