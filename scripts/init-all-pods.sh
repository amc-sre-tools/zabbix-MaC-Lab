#!/bin/bash
# =============================================================================
# Initialize All PODs - Zabbix Testing Environment
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Initialize all 5 PODs with proper network configuration
# Usage: ./scripts/init-all-pods.sh
# Requires: Podman 4.0+, .env file with secrets from OpenBao
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PODS_DIR="$PROJECT_ROOT/pods"

echo "=== Initializing All PODs ==="
echo "Project Root: $PROJECT_ROOT"
echo "Pods Directory: $PODS_DIR"

check_dependencies() {
    echo "[1/5] Checking dependencies..."
    
    if ! command -v podman &> /dev/null; then
        echo "Error: Podman is not installed"
        exit 1
    fi
    
    PODMAN_VERSION=$(podman --version | awk '{print $3}')
    echo "  Podman version: $PODMAN_VERSION"
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        echo "Warning: .env file not found. Creating from example..."
        cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
        echo "  Please edit .env with your secrets before continuing"
    fi
}

load_secrets() {
    echo "[2/5] Loading secrets from OpenBao..."
    
    if [ -f "$SCRIPT_DIR/load-secrets.sh" ]; then
        bash "$SCRIPT_DIR/load-secrets.sh" || true
    else
        echo "  Warning: load-secrets.sh not found, using .env directly"
    fi
}

create_podman_networks() {
    echo "[3/5] Creating Podman networks..."
    
    declare -A NETWORKS=(
        ["pod1-cicd-internal"]="10.99.10.0/24"
        ["pod2-monitoring-internal"]="10.99.20.0/24"
        ["pod3-services-internal"]="10.99.30.0/24"
        ["pod4-observability-internal"]="10.99.40.0/24"
        ["pod5-provisioning-internal"]="10.99.50.0/24"
    )
    
    for network in "${!NETWORKS[@]}"; do
        if podman network ls | grep -q "$network"; then
            echo "  Network $network already exists"
        else
            echo "  Creating network $network with subnet ${NETWORKS[$network]}"
            podman network create \
                --driver=bridge \
                --subnet="${NETWORKS[$network]}" \
                "$network" 2>/dev/null || true
        fi
    done
}

initialize_pods() {
    echo "[4/5] Initializing PODs..."
    
    local pods=(
        "pod1-cicd-devsecops"
        "pod2-monitoring-zabbix"
        "pod3-services-demo"
        "pod4-observability-dora"
        "pod5-provisioning"
    )
    
    for pod in "${pods[@]}"; do
        echo "  Setting up $pod..."
        
        if [ -f "$PODS_DIR/$pod/docker-compose.yml" ]; then
            cd "$PODS_DIR/$pod"
            
            podman compose config --services > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "    ✓ $pod docker-compose.yml is valid"
            else
                echo "    ✗ $pod docker-compose.yml has errors"
            fi
        else
            echo "    ✗ $pod/docker-compose.yml not found"
        fi
    done
    
    cd "$PROJECT_ROOT"
}

show_status() {
    echo "[5/5] PODs Status:"
    echo ""
    echo "To start a POD, run:"
    echo "  cd pods/<pod-name> && podman compose up -d"
    echo ""
    echo "Available PODs:"
    echo "  - pod1-cicd-devsecops    (Jenkins, SonarQube, OpenBao, Trivy)"
    echo "  - pod2-monitoring-zabbix (Zabbix 6.0, 7.0, 7.4, PostgreSQL)"
    echo "  - pod3-services-demo     (MySQL, Redis, RabbitMQ, Nginx, FastAPI)"
    echo "  - pod4-observability-dora (Prometheus, Grafana, Elasticsearch, OTel)"
    echo "  - pod5-provisioning       (Terraform, Ansible, Cloud CLIs)"
    echo ""
    echo "To start all PODs at once:"
    echo "  for pod in pods/*/; do (cd \$pod && podman compose up -d) & done; wait"
}

main() {
    check_dependencies
    load_secrets
    create_podman_networks
    initialize_pods
    show_status
    
    echo ""
    echo "=== Initialization Complete ==="
}

main "$@"