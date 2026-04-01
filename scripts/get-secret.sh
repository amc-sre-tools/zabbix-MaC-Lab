#!/bin/bash
# =============================================================================
# Script to retrieve secrets from OpenBao
# Usage: ./get-secret.sh <pod> <service>
# Example: ./get-secret.sh pod1 jenkins
# =============================================================================

BAO_ADDR="${BAO_ADDR:-http://localhost:8200}"
BAO_TOKEN="${BAO_TOKEN:-root-token-dev-only}"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <pod> <service>"
    echo ""
    echo "Available secrets:"
    echo ""
    echo "POD1 - CI/CD + DevSecOps:"
    echo "  pod1 jenkins     - Jenkins credentials"
    echo "  pod1 sonarqube  - SonarQube credentials"
    echo "  pod1 openbao    - OpenBao root token"
    echo ""
    echo "POD2 - Monitoring Zabbix:"
    echo "  pod2 postgresql - PostgreSQL credentials"
    echo "  pod2 zabbix     - Zabbix API and admin credentials"
    echo ""
    exit 1
fi

POD="$1"
SERVICE="$2"
PATH="secret/data/${POD}/${SERVICE}"

echo "Retrieving ${POD}/${SERVICE} from OpenBao..."
echo ""

RESPONSE=$(curl -s -H "X-Vault-Token: ${BAO_TOKEN}" "${BAO_ADDR}/v1/${PATH}")

if echo "$RESPONSE" | jq -e '.data.data' > /dev/null 2>&1; then
    echo "$RESPONSE" | jq -r '.data.data | to_entries | .[] | "\(.key): \(.value)"'
else
    echo "Error: Secret not found or invalid response"
    echo "$RESPONSE" | jq .
fi