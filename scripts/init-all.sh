#!/bin/bash

# =============================================================================
# Complete Initialization Script for Zabbix-MaC-Lab
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAO_ADDR="http://localhost:8200"
BAO_TOKEN="root-token-dev-only"

generate_password() {
    openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 12
}

store_secret() {
    local path="$1"
    local data="$2"
    curl -sf -X POST "$BAO_ADDR/v1/secret/data/$path" \
        -H "X-Vault-Token: $BAO_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"data\": $data}" > /dev/null 2>&1
}

echo "=== Generating and Storing Secrets ==="

ZABBIX60_PW=$(generate_password)
ZABBIX70_PW=$(generate_password)
ZABBIX74_PW=$(generate_password)
SONAR_PW=$(generate_password)
JENKINS_PW=$(generate_password)
POSTGRES_PW=$(generate_password)
MYSQL_PW=$(generate_password)
REDIS_PW=$(generate_password)
RABBITMQ_PW=$(generate_password)

echo "Storing POD1 secrets..."
store_secret "pod1/openbao" "{\"root_token\": \"$BAO_TOKEN\"}"
store_secret "pod1/jenkins" "{\"username\": \"admin\", \"password\": \"$JENKINS_PW\"}"
store_secret "pod1/sonarqube" "{\"username\": \"admin\", \"password\": \"$SONAR_PW\"}"

echo "Storing POD2 secrets..."
store_secret "pod2/postgresql" "{\"postgres_user\": \"zabbix\", \"postgres_password\": \"$POSTGRES_PW\"}"
store_secret "pod2/zabbix60" "{\"username\": \"Admin\", \"password\": \"$ZABBIX60_PW\"}"
store_secret "pod2/zabbix70" "{\"username\": \"Admin\", \"password\": \"$ZABBIX70_PW\"}"
store_secret "pod2/zabbix74" "{\"username\": \"Admin\", \"password\": \"$ZABBIX74_PW\"}"

echo "Storing POD3 secrets..."
store_secret "pod3/mysql" "{\"root_password\": \"$MYSQL_PW\", \"username\": \"appuser\", \"database\": \"appdb\"}"
store_secret "pod3/redis" "{\"password\": \"$REDIS_PW\"}"
store_secret "pod3/rabbitmq" "{\"username\": \"admin\", \"password\": \"$RABBITMQ_PW\"}"

echo ""
echo "=== Updating Zabbix Passwords ==="

fix_zabbix_password() {
    local port=$1
    local new_pw=$2
    
    podman exec pod2-monitoring-postgresql psql -U zabbix -d zabbix${port:0:2} -c "UPDATE users SET attempt_failed = 0, attempt_clock = 0 WHERE userid = 1;" 2>/dev/null || true
    
    curl -sf -X POST "http://localhost:$port/api_jsonrpc.php" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": {\"username\": \"Admin\", \"password\": \"zabbix\"}, \"id\": 1}" | jq -r '.result' | while read token; do
            if [ "$token" != "null" ]; then
                curl -sf -X POST "http://localhost:$port/api_jsonrpc.php" \
                    -H "Content-Type: application/json" \
                    -d "{\"jsonrpc\": \"2.0\", \"method\": \"user.update\", \"params\": {\"userid\": \"1\", \"passwd\": \"$new_pw\"}, \"auth\": \"$token\", \"id\": 2}" > /dev/null
                echo "Zabbix $port: Updated"
            fi
        done
}

fix_zabbix_password 8083 "$ZABBIX60_PW"
fix_zabbix_password 8081 "$ZABBIX70_PW"  
fix_zabbix_password 8082 "$ZABBIX74_PW"

echo ""
echo "=== Starting Zabbix Agents ==="

start_agent() {
    local name=$1
    local networks=$2
    local port=$3
    
    podman rm -f "$name" 2>/dev/null || true
    podman run -d --name "$name" \
        --network "$networks" \
        -e "ZBX_HOSTNAME=${name%-*}" \
        -e "ZBX_SERVER_HOST=pod2-zabbix-6.0-server,pod2-zabbix-7.0-server,pod2-zabbix-7.4-server" \
        -e "TZ=America/Bogota" \
        -p "$port:10050" \
        --privileged \
        zabbix/zabbix-agent:alpine-latest 2>/dev/null || true
}

start_agent pod1-zabbix-agent "pod1-cicd-devsecops_pod1-cicd-internal,pod2-monitoring-zabbix_pod2-monitoring-internal" 10051
start_agent pod3-zabbix-agent "pod3-services-demo_pod3-services-internal,pod2-monitoring-zabbix_pod2-monitoring-internal" 10052

echo ""
echo "=== Verifying Services ==="
podman ps --format "table {{.Names}}\t{{.Status}}" | grep -E "zabbix|agent"

echo ""
echo "=== Secrets Stored in OpenBao ==="
echo "Zabbix60: secret/data/pod2/zabbix60"
echo "Zabbix70: secret/data/pod2/zabbix70"
echo "Zabbix74: secret/data/pod2/zabbix74"
echo "SonarQube: secret/data/pod1/sonarqube"
echo "Jenkins: secret/data/pod1/jenkins"
echo "PostgreSQL: secret/data/pod2/postgresql"
echo "MySQL: secret/data/pod3/mysql"
echo "Redis: secret/data/pod3/redis"
echo "RabbitMQ: secret/data/pod3/rabbitmq"