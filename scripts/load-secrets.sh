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
    
    curl -s -H "X-Vault-Token: $BAO_TOKEN" \
        "$BAO_ADDR/v1/$path" | \
        python3 -c "import sys, json; data = json.load(sys.stdin); print(data['data']['data'].get('$key', ''))" 2>/dev/null || echo ""
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
    
    # POD1 - OpenBao
    echo "# POD1 - OpenBao" >> "$ENV_FILE"
    echo "BAO_DEV_ROOT_TOKEN_ID=$(load_secret 'secret/data/pod1/openbao' 'root_token')" >> "$ENV_FILE"
    echo "BAO_ADDR=${BAO_ADDR}" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    
    # POD1 - Jenkins
    echo "# POD1 - Jenkins" >> "$ENV_FILE"
    echo "JENKINS_USER=$(load_secret 'secret/data/pod1/jenkins' 'username')" >> "$ENV_FILE"
    echo "JENKINS_PASSWORD=$(load_secret 'secret/data/pod1/jenkins' 'password')" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    
    # POD1 - SonarQube
    echo "# POD1 - SonarQube" >> "$ENV_FILE"
    echo "SONARQUBE_USER=$(load_secret 'secret/data/pod1/sonarqube' 'username')" >> "$ENV_FILE"
    echo "SONARQUBE_PASSWORD=$(load_secret 'secret/data/pod1/sonarqube' 'password')" >> "$ENV_FILE"
    echo "SONARQUBE_DB_PASSWORD=$(load_secret 'secret/data/pod1/sonarqube' 'db_password')" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    
    # POD2 - PostgreSQL
    echo "# POD2 - PostgreSQL" >> "$ENV_FILE"
    echo "POSTGRES_USER=$(load_secret 'secret/data/pod2/postgresql' 'username')" >> "$ENV_FILE"
    echo "POSTGRES_PASSWORD=$(load_secret 'secret/data/pod2/postgresql' 'zabbix_password')" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    
    # POD2 - Zabbix
    echo "# POD2 - Zabbix" >> "$ENV_FILE"
    echo "ZABBIX_ADMIN_USER=$(load_secret 'secret/data/pod2/zabbix' 'admin_user')" >> "$ENV_FILE"
    echo "ZABBIX_ADMIN_PASSWORD=$(load_secret 'secret/data/pod2/zabbix' 'admin_password')" >> "$ENV_FILE"
    echo "ZABBIX_API_TOKEN=$(load_secret 'secret/data/pod2/zabbix' 'api_token')" >> "$ENV_FILE"
    
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