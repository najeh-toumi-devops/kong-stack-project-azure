import re
from typing import Optional, Dict, Any

class StockValidator:
    
    @staticmethod
    def validate_stock_data(data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
        required_fields = ['name', 'quantity', 'price', 'category']
        for field in required_fields:
            if field not in data or data[field] is None:
                return False, f"Champ requis manquant: {field}"
        
        name = data.get('name', '').strip()
        if not name or len(name) < 2 or len(name) > 100:
            return False, "Le nom doit contenir entre 2 et 100 caractères"
        
        try:
            quantity = int(data['quantity'])
            if quantity < 0:
                return False, "La quantité ne peut pas être négative"
        except (ValueError, TypeError):
            return False, "La quantité doit être un nombre entier"
        
        try:
            price = float(data['price'])
            if price < 0:
                return False, "Le prix ne peut pas être négatif"
        except (ValueError, TypeError):
            return False, "Le prix doit être un nombre"
        
        category = data.get('category', '').strip()
        if not category or len(category) < 2 or len(category) > 50:
            return False, "La catégorie doit contenir entre 2 et 50 caractères"
        
        if 'min_stock' in data and data['min_stock'] is not None:
            try:
                min_stock = int(data['min_stock'])
                if min_stock < 0:
                    return False, "Le stock minimum ne peut pas être négatif"
            except (ValueError, TypeError):
                return False, "Le stock minimum doit être un nombre entier"
        
        if 'max_stock' in data and data['max_stock'] is not None:
            try:
                max_stock = int(data['max_stock'])
                if max_stock < 0:
                    return False, "Le stock maximum ne peut pas être négatif"
            except (ValueError, TypeError):
                return False, "Le stock maximum doit être un nombre entier"
        
        if ('min_stock' in data and 'max_stock' in data and 
            data['min_stock'] is not None and data['max_stock'] is not None):
            if data['max_stock'] <= data['min_stock']:
                return False, "Le stock maximum doit être supérieur au stock minimum"
        
        return True, None
    
    @staticmethod
    def validate_quantity_update(quantity_change: int) -> tuple[bool, Optional[str]]:
        try:
            change = int(quantity_change)
            if change == 0:
                return False, "La modification de quantité ne peut pas être zéro"
            return True, None
        except (ValueError, TypeError):
            return False, "La modification de quantité doit être un nombre entier"

class QueryValidator:
    
    @staticmethod
    def validate_pagination_params(page: int, per_page: int) -> tuple[bool, Optional[str]]:
        if page < 1:
            return False, "Le numéro de page doit être supérieur à 0"
        if per_page < 1 or per_page > 100:
            return False, "Le nombre d'éléments par page doit être entre 1 et 100"
        return True, None
    
    @staticmethod
    def validate_sort_field(field: str, allowed_fields: list) -> tuple[bool, Optional[str]]:
        if field.lstrip('-') not in allowed_fields:
            return False, f"Champ de tri non autorisé: {field}"
        return True, None
