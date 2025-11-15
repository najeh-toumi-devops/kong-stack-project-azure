#!/bin/bash

echo "🔧 AJOUT DES ROUTES CRUD"

APP_DIR="/opt/stock-api"

# Arrêter le service
sudo systemctl stop stock-api

# 1. Créer le fichier validators.py
echo "1. 📝 Création de validators.py..."
sudo mkdir -p $APP_DIR/app/utils
sudo tee $APP_DIR/app/utils/validators.py > /dev/null << 'EOF'
def validate_stock_data(data, required_fields=None):
    if required_fields is None:
        required_fields = ['symbol', 'name', 'price']
    
    errors = []
    
    # Vérifier les champs requis
    for field in required_fields:
        if field not in data or not data[field]:
            errors.append(f"Le champ '{field}' est requis")
    
    # Validation du symbol
    if 'symbol' in data and data['symbol']:
        symbol = data['symbol'].strip().upper()
        if len(symbol) < 1 or len(symbol) > 10:
            errors.append("Le symbol doit avoir entre 1 et 10 caractères")
    
    # Validation du prix
    if 'price' in data and data['price']:
        try:
            price = float(data['price'])
            if price < 0:
                errors.append("Le prix ne peut pas être négatif")
        except (ValueError, TypeError):
            errors.append("Le prix doit être un nombre valide")
    
    # Validation de la quantité
    if 'quantity' in data and data['quantity']:
        try:
            quantity = int(data['quantity'])
            if quantity < 0:
                errors.append("La quantité ne peut pas être négative")
        except (ValueError, TypeError):
            errors.append("La quantité doit être un nombre entier valide")
    
    return errors
EOF

# 2. Mettre à jour stocks.py avec CRUD complet
echo "2. 🛣️ Mise à jour des routes stocks.py..."
sudo tee $APP_DIR/app/routes/stocks.py > /dev/null << 'EOF'
from flask import Blueprint, request, jsonify
from flasgger import swag_from
from datetime import datetime
from app.utils.validators import validate_stock_data

# Créer le blueprint
stocks_bp = Blueprint('stocks', __name__)

# Stockage en mémoire (remplacera par MongoDB plus tard)
stocks_db = {}

@stocks_bp.route('/health', methods=['GET'])
@swag_from({
    'responses': {
        200: {
            'description': 'Health check successful',
            'schema': {
                'type': 'object',
                'properties': {
                    'status': {'type': 'string'},
                    'timestamp': {'type': 'string'},
                    'service': {'type': 'string'},
                    'version': {'type': 'string'}
                }
            }
        }
    }
})
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'stock-api',
        'version': '1.0.0'
    })

@stocks_bp.route('/stocks', methods=['GET', 'POST'])
@swag_from({
    'parameters': [
        {
            'name': 'category',
            'in': 'query',
            'type': 'string',
            'required': False,
            'description': 'Filter by category'
        },
        {
            'name': 'search',
            'in': 'query', 
            'type': 'string',
            'required': False,
            'description': 'Search in name or description'
        }
    ],
    'responses': {
        200: {
            'description': 'List of stocks or stock created',
            'schema': {
                'type': 'object',
                'properties': {
                    'stocks': {
                        'type': 'array',
                        'items': {
                            'type': 'object',
                            'properties': {
                                'symbol': {'type': 'string'},
                                'name': {'type': 'string'},
                                'price': {'type': 'number'},
                                'currency': {'type': 'string'},
                                'quantity': {'type': 'integer'},
                                'category': {'type': 'string'},
                                'description': {'type': 'string'}
                            }
                        }
                    },
                    'count': {'type': 'integer'},
                    'message': {'type': 'string'}
                }
            }
        },
        201: {
            'description': 'Stock created successfully'
        }
    }
})
def handle_stocks():
    if request.method == 'GET':
        return get_all_stocks()
    elif request.method == 'POST':
        return create_stock()

def get_all_stocks():
    """Récupérer tous les stocks"""
    try:
        category = request.args.get('category')
        search = request.args.get('search', '').lower()
        
        filtered_stocks = []
        
        for symbol, stock in stocks_db.items():
            # Filtrer par catégorie
            if category and stock.get('category') != category:
                continue
            
            # Filtrer par recherche
            if search:
                name_match = search in stock.get('name', '').lower()
                desc_match = search in stock.get('description', '').lower()
                symbol_match = search in stock.get('symbol', '').lower()
                if not (name_match or desc_match or symbol_match):
                    continue
            
            filtered_stocks.append(stock)
        
        return jsonify({
            'stocks': filtered_stocks,
            'count': len(filtered_stocks),
            'message': 'Stocks retrieved successfully'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def create_stock():
    """Créer un nouveau stock"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        # Validation des données
        errors = validate_stock_data(data)
        if errors:
            return jsonify({'errors': errors}), 400
        
        symbol = data['symbol'].upper()
        
        # Vérifier si le stock existe déjà
        if symbol in stocks_db:
            return jsonify({'error': f'Stock with symbol {symbol} already exists'}), 409
        
        # Créer le stock
        stock = {
            'symbol': symbol,
            'name': data['name'],
            'price': float(data['price']),
            'currency': data.get('currency', 'USD'),
            'quantity': int(data.get('quantity', 0)),
            'category': data.get('category'),
            'description': data.get('description', ''),
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        # Sauvegarder
        stocks_db[symbol] = stock
        
        return jsonify({
            'stock': stock,
            'message': 'Stock created successfully'
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@stocks_bp.route('/stocks/<symbol>', methods=['GET', 'PUT', 'DELETE'])
def handle_stock(symbol):
    if request.method == 'GET':
        return get_stock(symbol)
    elif request.method == 'PUT':
        return update_stock(symbol)
    elif request.method == 'DELETE':
        return delete_stock(symbol)

def get_stock(symbol):
    """Récupérer un stock spécifique"""
    try:
        symbol = symbol.upper()
        stock = stocks_db.get(symbol)
        
        if not stock:
            return jsonify({'error': 'Stock not found'}), 404
        
        return jsonify({'stock': stock})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def update_stock(symbol):
    """Mettre à jour un stock"""
    try:
        symbol = symbol.upper()
        stock = stocks_db.get(symbol)
        
        if not stock:
            return jsonify({'error': 'Stock not found'}), 404
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        # Mettre à jour les champs
        updatable_fields = ['name', 'price', 'currency', 'quantity', 'category', 'description']
        
        for field in updatable_fields:
            if field in data:
                if field in ['price']:
                    stock[field] = float(data[field])
                elif field in ['quantity']:
                    stock[field] = int(data[field])
                else:
                    stock[field] = data[field]
        
        stock['updated_at'] = datetime.utcnow().isoformat()
        
        return jsonify({
            'stock': stock,
            'message': 'Stock updated successfully'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def delete_stock(symbol):
    """Supprimer un stock"""
    try:
        symbol = symbol.upper()
        
        if symbol not in stocks_db:
            return jsonify({'error': 'Stock not found'}), 404
        
        # Supprimer le stock
        del stocks_db[symbol]
        
        return jsonify({
            'message': 'Stock deleted successfully',
            'deleted_symbol': symbol
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
EOF

# 3. Redémarrer le service
echo "3. 🔄 Redémarrage du service..."
sudo systemctl start stock-api

# 4. Test
echo "4. 🧪 Test des nouvelles routes..."
sleep 3

echo "Test POST:"
curl -X POST http://localhost:8000/api/v1/stocks \
  -H "Content-Type: application/json" \
  -d '{"symbol": "AMZN", "name": "Amazon.com Inc.", "price": 154.65, "quantity": 800}' | python3 -m json.tool

echo ""
echo "Test GET:"
curl -s http://localhost:8000/api/v1/stocks | python3 -m json.tool

echo ""
echo "✅ CRUD routes ajoutées avec succès!"
