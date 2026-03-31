#!/bin/bash

# =============================================================================
# OpenBao Secrets Initialization Script
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Initializes secrets in OpenBao KV v2 store
# Usage: ./init-secrets.sh [OPTIONS]
# Options:
#   -t TOKEN   OpenBao token (default: from env BAO_TOKEN)
#   -a ADDR   OpenBao address (default: http://localhost:8200)
# Requirements: OpenBao running
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

export BAO_ADDR BAO_TOKEN

echo "=== OpenBao Secrets Initialization ==="

init_secrets() {
    echo "Initializing secrets in OpenBao..."
    
    curl -s -X POST "$BAO_ADDR/v1/sys/mounts/secret" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"type": "kv", "options": {"version": "2"}}'
    
    echo "[OK] Secrets engine enabled"
    
    local pg_password="${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}"
    local zabbix_password="${ZABBIX_PASSWORD:-$(openssl rand -base64 32)}"
    local fastapi_secret="${FASTAPI_SECRET_KEY:-$(openssl rand -base64 32)}"
    local fastapi_key="${FASTAPI_API_KEY:-$(openssl rand -base64 32)}"
    local zabbix_token="${ZABBIX_API_TOKEN:-$(openssl rand -base64 32)}"
    
    curl -s -X POST "$BAO_ADDR/v1/secret/data/postgresql/admin" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"postgres_password\": \"$pg_password\", \"zabbix_password\": \"$zabbix_password\"}}"
    
    echo "[OK] Secret: postgresql/admin"
    
    curl -s -X POST "$BAO_ADDR/v1/secret/data/zabbix/credentials" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"db_user\": \"zabbix\", \"db_password\": \"$zabbix_password\"}}"
    
    echo "[OK] Secret: zabbix/credentials"
    
    curl -s -X POST "$BAO_ADDR/v1/secret/data/zabbix/api-keys" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"api_token\": \"$zabbix_token\"}}"
    
    echo "[OK] Secret: zabbix/api-keys"
    
    curl -s -X POST "$BAO_ADDR/v1/secret/data/fastapi/app" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"secret_key\": \"$fastapi_secret\", \"api_key\": \"$fastapi_key\"}}"
    
    echo "[OK] Secret: fastapi/app"
    
    curl -s -X POST "$BAO_ADDR/v1/secret/data/nginx/ssl" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"data": {"cert": "cert_placeholder", "key": "key_placeholder", "dhparam": "dhparam_placeholder"}}'
    
    echo "[OK] Secret: nginx/ssl"
    
    echo ""
    echo "=== Secrets initialized successfully ==="
    echo ""
    echo "To read a secret:"
    echo "  curl -s -H 'X-Vault-Token: $BAO_TOKEN' $BAO_ADDR/v1/secret/data/postgresql/admin | jq"
    echo ""
    echo "To generate .env file from secrets:"
    echo "  ./scripts/load-secrets.sh"
}

verify_openbao() {
    echo "Verifying connection to OpenBao at $BAO_ADDR..."
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$BAO_ADDR/v1/sys/health" 2>/dev/null || echo "000")
    
    if [ "$status" = "200" ] || [ "$status" = "501" ]; then
        echo "[OK] OpenBao is available (status: $status)"
        init_secrets
    else
        echo "[ERROR] OpenBao is not available at $BAO_ADDR (status: $status)"
        exit 1
    fi
}

verify_openbao
