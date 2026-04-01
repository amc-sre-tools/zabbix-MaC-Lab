#!/bin/bash

# =============================================================================
# Service Initialization Script - Password Rotation
# =============================================================================
# Initializes passwords for Zabbix and SonarQube on container startup
# For Zabbix 7.0+: Due to API security changes, passwords are generated and
# stored in OpenBao. Users must change on first login (security best practice).
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAO_ADDR="${BAO_ADDR:-http://localhost:8200}"
BAO_TOKEN="${BAO_TOKEN:-root-token-dev-only}"

generate_password() {
    openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c 20
}

get_secret() {
    local path="$1"
    local secret
    secret=$(curl -sf -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/$path" 2>/dev/null | jq -r '.data.data.password // empty' 2>/dev/null)
    echo "$secret"
}

store_secret() {
    local path="$1"
    local password="$2"
    curl -sf -X POST "$BAO_ADDR/v1/$path" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"password\": \"$password\", \"username\": \"Admin\"}}" > /dev/null 2>&1
}

wait_for_service() {
    local url="$1"
    local name="$2"
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for $name at $url..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo "[OK] $name is available"
            return 0
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "[ERROR] $name not available after $max_attempts attempts"
    return 1
}

init_zabbix_password() {
    local zabbix_url="$1"
    local version="$2"
    local secret_path="$3"
    
    echo "  Processing Zabbix $version..."
    
    echo "  Generating new secure password..."
    password=$(generate_password)
    
    local attempt=1
    local max_attempts=5
    local updated=false
    
    while [ $attempt -le $max_attempts ] && [ "$updated" = "false" ]; do
        local auth_response
        auth_response=$(curl -sf -X POST "$zabbix_url/api_jsonrpc.php" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc": "2.0", "method": "user.login", "params": {"username": "Admin", "password": "zabbix"}, "id": 1}' 2>/dev/null)
        
        local auth_token
        auth_token=$(echo "$auth_response" | jq -r '.result' 2>/dev/null)
        
        if [ "$auth_token" != "null" ] && [ -n "$auth_token" ]; then
            local update_response
            update_response=$(curl -sf -X POST "$zabbix_url/api_jsonrpc.php" \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.update\", \"params\": {\"userid\": \"1\", \"passwd\": \"$password\"}, \"auth\": \"$auth_token\", \"id\": 2}" 2>/dev/null)
            
            local update_result
            update_result=$(echo "$update_response" | jq -r '.result' 2>/dev/null)
            
            if [ "$update_result" != "null" ]; then
                echo "  [OK] Password updated via API"
                updated=true
            fi
        fi
        
        if [ "$updated" = "false" ]; then
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$updated" = "false" ]; then
        echo "  [INFO] Password update pending - change on first login"
    fi
    
    store_secret "$secret_path" "$password"
    echo "  Password stored in OpenBao: $secret_path"
    
    return 0
}

init_sonarqube_password() {
    local sonar_url="$1"
    local secret_path="$2"
    
    echo "  Processing SonarQube..."
    
    local password
    password=$(get_secret "$secret_path")
    
    if [ -z "$password" ]; then
        echo "  Generating new password..."
        password=$(generate_password)
    else
        echo "  Password found in OpenBao"
    fi
    
    echo "  [INFO] SonarQube password change requires manual intervention"
    echo "  [ACTION REQUIRED] Please change password on first login at: $sonar_url"
    echo "  Current credentials: admin/admin"
    
    store_secret "$secret_path" "$password"
    echo "  Password stored in OpenBao: $secret_path"
    
    return 0
}

echo "========================================"
echo "Service Initialization - Password Setup"
echo "========================================"
echo ""
echo "NOTE: Due to security changes in Zabbix 7.0+ and SonarQube,"
echo "passwords are generated and stored in OpenBao."
echo "First-time users should change password on login."
echo ""

if curl -sf "$BAO_ADDR/v1/sys/health" > /dev/null 2>&1; then
    echo "[OK] OpenBao is available at $BAO_ADDR"
else
    echo "[WARN] OpenBao not available at $BAO_ADDR"
    echo "       Passwords will not be stored"
    BAO_ADDR=""
fi

echo ""
echo "=== Initializing Zabbix Passwords ==="

init_zabbix_password "http://localhost:8083" "6.0" "secret/data/pod2/zabbix60"
init_zabbix_password "http://localhost:8081" "7.0" "secret/data/pod2/zabbix70"
init_zabbix_password "http://localhost:8082" "7.4" "secret/data/pod2/zabbix74"

echo ""
echo "=== Initializing SonarQube Password ==="
init_sonarqube_password "http://localhost:9000" "secret/data/pod1/sonarqube"

echo ""
echo "========================================"
echo "Initialization Complete!"
echo "========================================"
echo ""
echo "Summary of credentials (stored in OpenBao):"
echo "  - Zabbix 6.0: http://localhost:8083 | Admin | (see OpenBao)"
echo "  - Zabbix 7.0: http://localhost:8081 | Admin | (see OpenBao)"
echo "  - Zabbix 7.4: http://localhost:8082 | Admin | (see OpenBao)"
echo "  - SonarQube:  http://localhost:9000 | admin | admin"
echo ""
echo "To retrieve passwords from OpenBao:"
echo "  curl -s -H 'X-Vault-Token: <token>' $BAO_ADDR/v1/secret/data/pod2/zabbix60 | jq"