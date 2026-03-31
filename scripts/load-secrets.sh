#!/bin/bash

# =============================================================================
# Environment Loader - Load secrets from OpenBao to .env
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Loads secrets from OpenBao and generates .env file
# Usage: ./scripts/load-secrets.sh
# Requirements: OpenBao running with secrets initialized
# =============================================================================

set -e

BAO_ADDR="${BAO_ADDR:-http://localhost:8200}"
BAO_TOKEN="${BAO_TOKEN:-root-token-dev-only}"

ENV_FILE=".env"

echo "=== Loading Secrets from OpenBao ==="

load_secret() {
    local path=$1
    local key=$2
    local var_name=$3
    
    local value=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/$path" | \
        python3 -c "import sys, json; data = json.load(sys.stdin); print(data['data']['data'].get('$key', ''))" 2>/dev/null || echo "")
    
    if [ -n "$value" ]; then
        echo "$var_name=$value"
    fi
}

generate_env_file() {
    echo "Generating $ENV_FILE from OpenBao..."
    
    cat > "$ENV_FILE" << 'EOF'
# =============================================================================
# Environment Variables - Auto-generated from OpenBao
# =============================================================================
# DO NOT COMMIT THIS FILE TO VERSION CONTROL!
# =============================================================================

EOF
    
    # OpenBao
    echo "BAO_DEV_ROOT_TOKEN_ID=${BAO_TOKEN}" >> "$ENV_FILE"
    echo "BAO_ADDR=${BAO_ADDR}" >> "$ENV_FILE"
    
    # PostgreSQL secrets
    local pg_password=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/secret/data/postgresql/admin" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['data']['data'].get('postgres_password', ''))" 2>/dev/null || echo "")
    
    local zabbix_password=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/secret/data/postgresql/admin" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['data']['data'].get('zabbix_password', ''))" 2>/dev/null || echo "")
    
    echo "POSTGRES_DB=zabbix" >> "$ENV_FILE"
    echo "POSTGRES_USER=zabbix" >> "$ENV_FILE"
    echo "POSTGRES_PASSWORD=${zabbix_password}" >> "$ENV_FILE"
    
    # FastAPI secrets
    local fastapi_secret=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/secret/data/fastapi/app" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['data']['data'].get('secret_key', ''))" 2>/dev/null || echo "")
    
    local fastapi_key=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/secret/data/fastapi/app" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['data']['data'].get('api_key', ''))" 2>/dev/null || echo "")
    
    echo "FASTAPI_SECRET_KEY=${fastapi_secret}" >> "$ENV_FILE"
    echo "FASTAPI_API_KEY=${fastapi_key}" >> "$ENV_FILE"
    
    # Zabbix API
    local zabbix_api_token=$(curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/secret/data/zabbix/api-keys" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['data']['data'].get('api_token', ''))" 2>/dev/null || echo "")
    
    echo "ZABBIX_API_TOKEN=${zabbix_api_token}" >> "$ENV_FILE"
    
    echo "[OK] $ENV_FILE generated successfully"
    echo ""
    echo "=== Environment file created ==="
    echo "File: $ENV_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Review $ENV_FILE"
    echo "2. Run: podman compose up -d"
}

verify_openbao() {
    echo "Verifying connection to OpenBao..."
    
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$BAO_ADDR/v1/sys/health" 2>/dev/null || echo "000")
    
    if [ "$status" = "200" ] || [ "$status" = "501" ]; then
        echo "[OK] OpenBao is available (status: $status)"
        generate_env_file
    else
        echo "[ERROR] OpenBao is not available at $BAO_ADDR"
        echo "Please ensure OpenBao is running:"
        echo "  podman compose up -d openbao"
        exit 1
    fi
}

verify_openbao
