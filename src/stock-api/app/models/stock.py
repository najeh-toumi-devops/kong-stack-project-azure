from datetime import datetime
from typing import Optional, Dict, Any
from bson import ObjectId

class Stock:
    def __init__(self, 
                 name: str,
                 description: str,
                 quantity: int,
                 price: float,
                 category: str,
                 min_stock: int = 10,
                 max_stock: int = 1000,
                 supplier: str = "",
                 sku: str = "",
                 product_id: str = None,
                 _id: Optional[ObjectId] = None,
                 created_at: Optional[datetime] = None,
                 updated_at: Optional[datetime] = None):
        
        self._id = _id or ObjectId()
        self.product_id = product_id or str(self._id)
        self.name = name
        self.description = description
        self.quantity = quantity
        self.price = price
        self.category = category
        self.min_stock = min_stock
        self.max_stock = max_stock
        self.supplier = supplier
        self.sku = sku
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": str(self._id),
            "product_id": self.product_id,
            "name": self.name,
            "description": self.description,
            "quantity": self.quantity,
            "price": self.price,
            "category": self.category,
            "min_stock": self.min_stock,
            "max_stock": self.max_stock,
            "supplier": self.supplier,
            "sku": self.sku,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "stock_value": self.quantity * self.price,
            "low_stock_alert": self.quantity <= self.min_stock,
            "over_stock_alert": self.quantity >= self.max_stock
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Stock':
        _id = data.get('_id')
        if _id and not isinstance(_id, ObjectId):
            _id = ObjectId(_id)
        
        created_at = data.get('created_at')
        if created_at and isinstance(created_at, str):
            created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        
        updated_at = data.get('updated_at')
        if updated_at and isinstance(updated_at, str):
            updated_at = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
        
        return cls(
            _id=_id,
            product_id=data.get('product_id'),
            name=data.get('name'),
            description=data.get('description', ''),
            quantity=data.get('quantity', 0),
            price=data.get('price', 0.0),
            category=data.get('category', 'general'),
            min_stock=data.get('min_stock', 10),
            max_stock=data.get('max_stock', 1000),
            supplier=data.get('supplier', ''),
            sku=data.get('sku', ''),
            created_at=created_at,
            updated_at=updated_at
        )
    
    def update_quantity(self, new_quantity: int) -> None:
        self.quantity = new_quantity
        self.updated_at = datetime.utcnow()
    
    def add_stock(self, quantity: int) -> None:
        self.update_quantity(self.quantity + quantity)
    
    def remove_stock(self, quantity: int) -> None:
        if self.quantity - quantity < 0:
            raise ValueError("Quantité insuffisante en stock")
        self.update_quantity(self.quantity - quantity)

class StockHistory:
    def __init__(self, 
                 product_id: str,
                 action: str,
                 quantity_change: int,
                 previous_quantity: int,
                 new_quantity: int,
                 user: str = "system",
                 notes: str = "",
                 _id: Optional[ObjectId] = None,
                 timestamp: Optional[datetime] = None):
        
        self._id = _id or ObjectId()
        self.product_id = product_id
        self.action = action
        self.quantity_change = quantity_change
        self.previous_quantity = previous_quantity
        self.new_quantity = new_quantity
        self.user = user
        self.notes = notes
        self.timestamp = timestamp or datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": str(self._id),
            "product_id": self.product_id,
            "action": self.action,
            "quantity_change": self.quantity_change,
            "previous_quantity": self.previous_quantity,
            "new_quantity": self.new_quantity,
            "user": self.user,
            "notes": self.notes,
            "timestamp": self.timestamp.isoformat()
        }
