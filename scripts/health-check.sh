#!/bin/bash

# =============================================================================
# Health Check Script for Zabbix Testing Environment
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Verifies status of all services in the environment
# Usage: ./health-check.sh
# =============================================================================

echo "=== Zabbix Testing Environment - Health Check ==="
echo ""

check_service() {
    local name=$1
    local url=$2
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null | grep -q "200\|201\|302"; then
        echo "[OK] $name: $url"
    else
        echo "[FAIL] $name: $url"
    fi
}

echo "=== Servicios ==="
check_service "OpenBao" "http://localhost:8200/v1/sys/health"
check_service "Zabbix 6.0 Web" "http://localhost:8080"
check_service "Zabbix 7.0 Web" "http://localhost:8081"
check_service "Zabbix 7.4 Web" "http://localhost:8082"
check_service "Nginx" "http://localhost:80"
check_service "FastAPI" "http://localhost:8000"

echo ""
echo "=== Contenedores Podman ==="
podman ps --format "{{.Names}}\t{{.Status}}" 2>/dev/null || echo "Podman no disponible"

echo ""
echo "=== Redes Podman ==="
podman network ls 2>/dev/null || echo "Podman no disponible"

echo ""
echo "=== Logs de FastAPI (últimas 5 líneas) ==="
tail -n 5 /data/fastapi/logs/app.log 2>/dev/null || echo "Logs no disponibles"
