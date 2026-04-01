#!/bin/bash

# =============================================================================
# Zabbix Password Initialization Script
# =============================================================================
# Changes the default Admin password on first Zabbix startup
# Usage: Run as init script in Zabbix container or standalone
# =============================================================================

set -e

ZABBIX_URL="${ZBX_SERVER_URL:-http://localhost:8080}"
NEW_PASSWORD="${ZABBIX_ADMIN_PASSWORD:-}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-zabbix}"

wait_for_zabbix() {
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for Zabbix API..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$ZABBIX_URL/api_jsonrpc.php" > /dev/null 2>&1; then
            echo "Zabbix API is available"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "Timeout waiting for Zabbix API"
    return 1
}

init_zabbix_password() {
    if [ -z "$NEW_PASSWORD" ]; then
        echo "No ZABBIX_ADMIN_PASSWORD set, skipping password change"
        return 0
    fi
    
    echo "Initializing Zabbix admin password..."
    
    local attempt=1
    local max_attempts=10
    
    while [ $attempt -le $max_attempts ]; do
        local auth_response
        auth_response=$(curl -sf -X POST "$ZABBIX_URL/api_jsonrpc.php" \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": {\"username\": \"Admin\", \"password\": \"$DEFAULT_PASSWORD\"}, \"id\": 1}" 2>/dev/null)
        
        local auth_token
        auth_token=$(echo "$auth_response" | jq -r '.result' 2>/dev/null)
        
        if [ "$auth_token" != "null" ] && [ -n "$auth_token" ]; then
            echo "Authenticated to Zabbix"
            
            local update_response
            update_response=$(curl -sf -X POST "$ZABBIX_URL/api_jsonrpc.php" \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.update\", \"params\": {\"userid\": \"1\", \"passwd\": \"$NEW_PASSWORD\"}, \"auth\": \"$auth_token\", \"id\": 2}" 2>/dev/null)
            
            local update_result
            update_result=$(echo "$update_response" | jq -r '.result' 2>/dev/null)
            
            if [ "$update_result" != "null" ]; then
                echo "Password updated successfully for Zabbix"
                return 0
            fi
        fi
        
        echo "  Attempt $attempt/$max_attempts - retrying..."
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "Failed to update Zabbix password"
    return 1
}

echo "=== Zabbix Password Initialization ==="
wait_for_zabbix
init_zabbix_password
echo "=== Initialization Complete ==="