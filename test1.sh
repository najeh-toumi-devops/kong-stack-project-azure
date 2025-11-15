#!/bin/bash

echo "🔍 DIAGNOSTIC SUR LE PORT 8000"

# Test de tous les endpoints sur le port 8000
echo "1. Test des endpoints sur le port 8000:"

echo ""
echo "📍 Test / :"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8000/

echo ""
echo "📍 Test /api/v1/health :"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8000/api/v1/health

echo ""
echo "📍 Test /api/v1/stocks :"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8000/api/v1/stocks

echo ""
echo "📍 Test /swagger/ :"
curl -s -w "HTTP Status: %{http_code}\n" http://localhost:8000/swagger/

echo ""
echo "2. Vérification de NGINX:"
sudo systemctl status nginx --no-pager

echo ""
echo "3. Vérification des processus écoutant sur le port 8000:"
sudo netstat -tlnp | grep :8000
sudo ss -tlnp | grep :8000

echo ""
echo "4. Logs NGINX:"
sudo tail -20 /var/log/nginx/error.log
