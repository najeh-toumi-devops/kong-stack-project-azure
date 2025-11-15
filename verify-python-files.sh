#!/bin/bash

echo "🔍 VÉRIFICATION DES FICHIERS PYTHON"

REPO_DIR="/home/azureuser/kong-stack-project-azure/src/stock-api"

# Vérifier la structure
echo "1. Structure des fichiers Python:"
find $REPO_DIR -name "*.py" -type f | sort

echo ""
echo "2. Fichiers __init__.py (doivent exister):"
find $REPO_DIR -name "__init__.py" -type f | sort

echo ""
echo "3. Contenu de app/__init__.py:"
if [ -f "$REPO_DIR/app/__init__.py" ]; then
    head -10 "$REPO_DIR/app/__init__.py"
else
    echo "❌ FICHIER MANQUANT: app/__init__.py"
fi

echo ""
echo "4. Test d'import Python:"
cd $REPO_DIR
python3 -c "
try:
    from app import create_app
    print('✅ Import de create_app: OK')
    app = create_app()
    print('✅ Création de app: OK')
    print('Routes disponibles:', [str(rule) for rule in app.url_map.iter_rules()])
except Exception as e:
    print('❌ Erreur:', e)
    import traceback
    traceback.print_exc()
"
