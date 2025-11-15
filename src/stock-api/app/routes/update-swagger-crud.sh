#!/bin/bash

echo "🔧 AJOUT DES DOCUMENTATIONS SWAGGER POUR CRUD"

APP_DIR="/opt/stock-api"

# Arrêter le service
sudo systemctl stop stock-api

# Mettre à jour le fichier routes avec documentation Swagger complète
echo "📝 Mise à jour de stocks.py avec documentation Swagger..."
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
    'tags': ['Health'],
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

@stocks_bp.route('/stocks', methods=['GET'])
@swag_from({
    'tags': ['Stocks'],
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
            'description': 'List of stocks retrieved successfully',
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
                                'description': {'type': 'string'},
                                'created_at': {'type': 'string'},
                                'updated_at': {'type': 'string'}
                            }
                        }
                    },
                    'count': {'type': 'integer'},
                    'message': {'type': 'string'}
                }
            }
        }
    }
})
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

@stocks_bp.route('/stocks', methods=['POST'])
@swag_from({
    'tags': ['Stocks'],
    'parameters': [
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'required': ['symbol', 'name', 'price'],
                'properties': {
                    'symbol': {
                        'type': 'string',
                        'example': 'AAPL',
                        'description': 'Stock symbol (unique)'
                    },
                    'name': {
                        'type': 'string', 
                        'example': 'Apple Inc.',
                        'description': 'Company name'
                    },
                    'price': {
                        'type': 'number',
                        'example': 182.63,
                        'description': 'Current stock price'
                    },
                    'currency': {
                        'type': 'string',
                        'example': 'USD',
                        'description': 'Currency code',
                        'default': 'USD'
                    },
                    'quantity': {
                        'type': 'integer',
                        'example': 1000,
                        'description': 'Available quantity',
                        'default': 0
                    },
                    'category': {
                        'type': 'string',
                        'example': 'Technology',
                        'description': 'Stock category'
                    },
                    'description': {
                        'type': 'string',
                        'example': 'iPhone manufacturer',
                        'description': 'Company description'
                    }
                }
            }
        }
    ],
    'responses': {
        201: {
            'description': 'Stock created successfully',
            'schema': {
                'type': 'object',
                'properties': {
                    'stock': {
                        'type': 'object',
                        'properties': {
                            'symbol': {'type': 'string'},
                            'name': {'type': 'string'},
                            'price': {'type': 'number'},
                            'currency': {'type': 'string'},
                            'quantity': {'type': 'integer'},
                            'category': {'type': 'string'},
                            'description': {'type': 'string'},
                            'created_at': {'type': 'string'},
                            'updated_at': {'type': 'string'}
                        }
                    },
                    'message': {'type': 'string'}
                }
            }
        },
        400: {
            'description': 'Validation error'
        },
        409: {
            'description': 'Stock already exists'
        }
    }
})
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

@stocks_bp.route('/stocks/<symbol>', methods=['GET'])
@swag_from({
    'tags': ['Stocks'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Stock symbol'
        }
    ],
    'responses': {
        200: {
            'description': 'Stock details',
            'schema': {
                'type': 'object',
                'properties': {
                    'stock': {
                        'type': 'object',
                        'properties': {
                            'symbol': {'type': 'string'},
                            'name': {'type': 'string'},
                            'price': {'type': 'number'},
                            'currency': {'type': 'string'},
                            'quantity': {'type': 'integer'},
                            'category': {'type': 'string'},
                            'description': {'type': 'string'},
                            'created_at': {'type': 'string'},
                            'updated_at': {'type': 'string'}
                        }
                    }
                }
            }
        },
        404: {
            'description': 'Stock not found'
        }
    }
})
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

@stocks_bp.route('/stocks/<symbol>', methods=['PUT'])
@swag_from({
    'tags': ['Stocks'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Stock symbol'
        },
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'properties': {
                    'name': {
                        'type': 'string', 
                        'example': 'Apple Inc.',
                        'description': 'Company name'
                    },
                    'price': {
                        'type': 'number',
                        'example': 185.00,
                        'description': 'Current stock price'
                    },
                    'currency': {
                        'type': 'string',
                        'example': 'USD',
                        'description': 'Currency code'
                    },
                    'quantity': {
                        'type': 'integer',
                        'example': 1200,
                        'description': 'Available quantity'
                    },
                    'category': {
                        'type': 'string',
                        'example': 'Technology',
                        'description': 'Stock category'
                    },
                    'description': {
                        'type': 'string',
                        'example': 'iPhone and Mac manufacturer',
                        'description': 'Company description'
                    }
                }
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Stock updated successfully',
            'schema': {
                'type': 'object',
                'properties': {
                    'stock': {
                        'type': 'object',
                        'properties': {
                            'symbol': {'type': 'string'},
                            'name': {'type': 'string'},
                            'price': {'type': 'number'},
                            'currency': {'type': 'string'},
                            'quantity': {'type': 'integer'},
                            'category': {'type': 'string'},
                            'description': {'type': 'string'},
                            'created_at': {'type': 'string'},
                            'updated_at': {'type': 'string'}
                        }
                    },
                    'message': {'type': 'string'}
                }
            }
        },
        404: {
            'description': 'Stock not found'
        }
    }
})
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

@stocks_bp.route('/stocks/<symbol>', methods=['DELETE'])
@swag_from({
    'tags': ['Stocks'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Stock symbol'
        }
    ],
    'responses': {
        200: {
            'description': 'Stock deleted successfully',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'deleted_symbol': {'type': 'string'}
                }
            }
        },
        404: {
            'description': 'Stock not found'
        }
    }
})
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

# Redémarrer le service
echo "🔄 Redémarrage du service..."
sudo systemctl start stock-api

# Attendre le démarrage
sleep 3

echo ""
echo "✅ Documentation Swagger mise à jour !"
echo ""
echo "🌐 Accède maintenant à Swagger sur:"
echo "   http://api-public-ip.francecentral.cloudapp.azure.com/swagger/"
echo ""
echo "📋 Tu verras maintenant:"
echo "   - POST /stocks pour créer des produits"
echo "   - GET /stocks pour lister les produits"  
echo "   - GET /stocks/{symbol} pour récupérer un produit"
echo "   - PUT /stocks/{symbol} pour modifier un produit"
echo "   - DELETE /stocks/{symbol} pour supprimer un produit"
