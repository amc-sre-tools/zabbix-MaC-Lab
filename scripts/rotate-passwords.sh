#!/bin/bash

# =============================================================================
# Password Rotation Script for Zabbix and SonarQube
# =============================================================================
# Author: Andrés M. Correa
# Description: Changes default passwords and stores in OpenBao
# Usage: ./rotate-passwords.sh [OPTIONS]
# Options:
#   -t TOKEN   OpenBao token (default: from env BAO_TOKEN)
#   -a ADDR    OpenBao address (default: http://localhost:8200)
# Requirements: OpenBao, Zabbix, and SonarQube containers running
# =============================================================================

set -e

BAO_ADDR="${BAO_ADDR:-http://localhost:8200}"
BAO_TOKEN="${BAO_TOKEN:-root-token-dev-only}"

while getopts "t:a:h" opt; do
    case $opt in
        t) BAO_TOKEN="$OPTARG" ;;
        a) BAO_ADDR="$OPTARG" ;;
        h) echo "Usage: $0 [-t token] [-a address]"; exit 0 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

generate_password() {
    openssl rand -base64 16 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c 20
}

wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $name..."
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

rotate_zabbix_passwords() {
    echo ""
    echo "=== Rotating Zabbix Passwords ==="
    
    local versions=("60" "70" "74")
    local ports=("8083" "8081" "8082")
    local zabbix_password
    
    for i in "${!versions[@]}"; do
        local version="${versions[$i]}"
        local port="${ports[$i]}"
        local zabbix_url="http://localhost:$port"
        
        echo "Processing Zabbix $version on port $port..."
        
        zabbix_password=$(generate_password)
        
        local attempt=1
        local max_attempts=10
        local success=false
        
        while [ $attempt -le $max_attempts ] && [ "$success" = "false" ]; do
            local auth_response
            if auth_response=$(curl -sf -X POST "$zabbix_url/api_jsonrpc.php" \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": {\"username\": \"Admin\", \"password\": \"zabbix\"}, \"id\": 1}" 2>/dev/null); then
                
                local auth_token
                auth_token=$(echo "$auth_response" | jq -r '.result' 2>/dev/null)
                
                if [ "$auth_token" != "null" ] && [ -n "$auth_token" ]; then
                    echo "  Authenticated to Zabbix $version"
                    
                    curl -sf -X POST "$zabbix_url/api_jsonrpc.php" \
                        -H "Content-Type: application/json" \
                        -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.updateProfile\", \"params\": {\"password\": \"$zabbix_password\", \"current_password\": \"zabbix\"}, \"auth\": \"$auth_token\", \"id\": 2}" > /dev/null
                    
                    sleep 2
                    
                    local verify_result
                    verify_result=$(curl -sf -X POST "$zabbix_url/api_jsonrpc.php" \
                        -H "Content-Type: application/json" \
                        -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": {\"username\": \"Admin\", \"password\": \"$zabbix_password\"}, \"id\": 3}" 2>/dev/null)
                    
                    local verify_token
                    verify_token=$(echo "$verify_result" | jq -r '.result' 2>/dev/null)
                    
                    if [ "$verify_token" != "null" ] && [ -n "$verify_token" ]; then
                        echo "  Password updated for Zabbix $version"
                        
                        curl -s -X POST "$BAO_ADDR/v1/secret/data/pod2/zabbix$version" \
                            -H "X-Vault-Token: $BAO_TOKEN" \
                            -H "Content-Type: application/json" \
                            -d "{\"data\": {\"password\": \"$zabbix_password\", \"username\": \"Admin\"}}"
                        
                        echo "  Credentials stored in OpenBao: secret/data/pod2/zabbix$version"
                        success=true
                    else
                        echo "  Password verification failed for Zabbix $version"
                    fi
                fi
            fi
            
            if [ "$success" = "false" ]; then
                echo "  Attempt $attempt/$max_attempts - retrying..."
                sleep 3
                attempt=$((attempt + 1))
            fi
        done
        
        if [ "$success" = "false" ]; then
            echo "  [WARN] Could not update Zabbix $version - skipping"
        fi
    done
}

rotate_sonarqube_password() {
    echo ""
    echo "=== Rotating SonarQube Password ==="
    
    local sonarqube_password=$(generate_password)
    local sonarqube_url="http://localhost:9000"
    
    wait_for_service "$sonarqube_url/api/system/status" "SonarQube"
    
    local attempt=1
    local max_attempts=10
    local success=false
    
    while [ $attempt -le $max_attempts ] && [ "$success" = "false" ]; do
        local cookie_file="/tmp/sonar_cookies_$$.txt"
        
        local login_response
        if login_response=$(curl -sf -c "$cookie_file" -L -X POST "$sonarqube_url/sessions/login" \
            -d "login=admin&password=zabbix" 2>/dev/null); then
            
            local change_response
            if change_response=$(curl -sf -b "$cookie_file" -X POST "$sonarqube_url/api/users/change_password" \
                -d "login=admin&previousPassword=zabbix&password=$sonarqube_password" 2>/dev/null); then
                
                rm -f "$cookie_file"
                
                echo "Password updated for SonarQube"
                
                curl -s -X POST "$BAO_ADDR/v1/secret/data/pod1/sonarqube" \
                    -H "X-Vault-Token: $BAO_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"data\": {\"password\": \"$sonarqube_password\", \"username\": \"admin\", \"url\": \"$sonarqube_url\"}}"
                
                echo "Credentials stored in OpenBao: secret/data/pod1/sonarqube"
                success=true
            else
                rm -f "$cookie_file"
            fi
        fi
        
        if [ "$success" = "false" ]; then
            echo "  Attempt $attempt/$max_attempts - retrying..."
            sleep 3
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$success" = "false" ]; then
        echo "[WARN] Could not update SonarQube password - trying alternate method"
        alt_sonarqube_password "$sonarqube_password"
    fi
}

alt_sonarqube_password() {
    local new_password="$1"
    local sonarqube_url="http://localhost:9000"
    
    echo "  Trying alternate method: Direct database password generation"
    
    local temp_password=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 16)
    
    local attempt=1
    local max_attempts=5
    
    while [ $attempt -le $max_attempts ]; do
        local cookie_file="/tmp/sonar_alt_$$.txt"
        
        curl -sf -c "$cookie_file" -L -X POST "$sonarqube_url/sessions/login" \
            -d "login=admin&password=admin" > /dev/null 2>&1
        
        if [ -f "$cookie_file" ] && [ -s "$cookie_file" ]; then
            local result
            result=$(curl -sf -b "$cookie_file" -X POST "$sonarqube_url/api/users/change_password" \
                -d "login=admin&previousPassword=zabbix&password=$new_password" 2>&1)
            
            rm -f "$cookie_file"
            
            if [ -z "$result" ]; then
                echo "  Password updated successfully via alternate method"
                
                curl -s -X POST "$BAO_ADDR/v1/secret/data/pod1/sonarqube" \
                    -H "X-Vault-Token: $BAO_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"data\": {\"password\": \"$new_password\", \"username\": \"admin\", \"url\": \"$sonarqube_url\"}}"
                
                echo "  Credentials stored in OpenBao: secret/data/pod1/sonarqube"
                return 0
            fi
        fi
        
        rm -f "$cookie_file"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "  [WARN] Alternate method also failed - storing generated password anyway"
    curl -s -X POST "$BAO_ADDR/v1/secret/data/pod1/sonarqube" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"password\": \"$new_password\", \"username\": \"admin\", \"url\": \"$sonarqube_url\"}}"
}

generate_env_file() {
    echo ""
    echo "=== Updating .env file ==="
    
    local zabbix60_pw=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/pod2/zabbix60" | jq -r '.data.data.password // empty')
    local zabbix70_pw=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/pod2/zabbix70" | jq -r '.data.data.password // empty')
    local zabbix74_pw=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/pod2/zabbix74" | jq -r '.data.data.password // empty')
    local sonarqube_pw=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/secret/data/pod1/sonarqube" | jq -r '.data.data.password // empty')
    
    local env_file="$SCRIPT_DIR/../.env"
    
    if [ -f "$env_file" ]; then
        if [ -n "$zabbix60_pw" ]; then
            sed -i "s/ZABBIX60_PASSWORD=.*/ZABBIX60_PASSWORD=$zabbix60_pw/" "$env_file"
        fi
        if [ -n "$zabbix70_pw" ]; then
            sed -i "s/ZABBIX70_PASSWORD=.*/ZABBIX70_PASSWORD=$zabbix70_pw/" "$env_file"
        fi
        if [ -n "$zabbix74_pw" ]; then
            sed -i "s/ZABBIX74_PASSWORD=.*/ZABBIX74_PASSWORD=$zabbix74_pw/" "$env_file"
        fi
        if [ -n "$sonarqube_pw" ]; then
            sed -i "s/SONARQUBE_PASSWORD=.*/SONARQUBE_PASSWORD=$sonarqube_pw/" "$env_file"
        fi
        echo "[OK] .env file updated"
    else
        echo "[WARN] .env file not found"
    fi
}

echo "========================================"
echo "Password Rotation Script"
echo "========================================"

wait_for_service "http://localhost:8200/v1/sys/health" "OpenBao"

rotate_zabbix_passwords
rotate_sonarqube_password
update_env_file

echo ""
echo "========================================"
echo "Password rotation completed!"
echo "========================================"