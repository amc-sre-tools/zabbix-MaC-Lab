#!/bin/bash
# =============================================================================
# Health Check Script - Zabbix Testing Environment
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Verify health of all PODs and services
# Usage: ./scripts/health-check.sh [--verbose] [--json]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PODS_DIR="$PROJECT_ROOT/pods"

VERBOSE=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v) VERBOSE=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

declare -A POD_PORTS=(
    ["pod1-openbao"]="8200"
    ["pod1-jenkins"]="8080"
    ["pod1-sonarqube"]="9000"
    ["pod2-postgresql"]="5432"
    ["pod2-zabbix-web-6.0"]="8080"
    ["pod2-zabbix-web-7.0"]="8081"
    ["pod2-zabbix-web-7.4"]="8082"
    ["pod2-zabbix-server-6.0"]="10060"
    ["pod2-zabbix-server-7.0"]="10070"
    ["pod2-zabbix-server-7.4"]="10074"
    ["pod3-mysql"]="3306"
    ["pod3-redis"]="6379"
    ["pod3-rabbitmq"]="5672"
    ["pod3-rabbitmq-management"]="15672"
    ["pod3-nginx"]="80"
    ["pod3-fastapi"]="8000"
    ["pod3-node-exporter"]="9100"
    ["pod4-prometheus"]="9090"
    ["pod4-alertmanager"]="9093"
    ["pod4-grafana"]="3000"
    ["pod4-elasticsearch"]="9200"
    ["pod4-kibana"]="5601"
    ["pod4-cadvisor"]="8080"
)

check_container_health() {
    local container=$1
    local status=$(podman inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    echo "$status"
}

check_port() {
    local host=$1
    local port=$2
    
    if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_service() {
    local pod=$1
    local port=$2
    local name=$3
    
    if check_port localhost "$port"; then
        echo "UP"
    else
        echo "DOWN"
    fi
}

check_pod() {
    local pod_name=$1
    local pod_dir="$PODS_DIR/$pod_name"
    
    if [ ! -f "$pod_dir/docker-compose.yml" ]; then
        echo "NOT_FOUND"
        return
    fi
    
    cd "$pod_dir"
    
    local running=$(podman compose ps --format json 2>/dev/null | jq -r '.[].State' 2>/dev/null || echo "stopped")
    
    if echo "$running" | grep -q "running"; then
        echo "RUNNING"
    else
        echo "STOPPED"
    fi
    
    cd "$PROJECT_ROOT"
}

health_check_json() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "pods": ['
    
    local first=true
    for pod in pods/*/; do
        pod_name=$(basename "$pod")
        
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false
        
        local status=$(check_pod "$pod_name")
        local containers=$(podman ps --format "{{.Names}}" 2>/dev/null | grep "^pod" | wc -l)
        
        echo "    {"
        echo '      "name": "'$pod_name'",'
        echo '      "status": "'$status'",'
        echo '      "containers": '$containers
        echo -n "    }"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

health_check_verbose() {
    echo "========================================"
    echo "     PODMAN HEALTH CHECK REPORT        "
    echo "========================================"
    echo "Date: $(date)"
    echo ""
    
    echo "=== POD Status ==="
    for pod in pods/*/; do
        pod_name=$(basename "$pod")
        status=$(check_pod "$pod_name")
        
        if [ "$status" = "RUNNING" ]; then
            echo "✓ $pod_name: RUNNING"
        else
            echo "✗ $pod_name: $status"
        fi
    done
    
    echo ""
    echo "=== Container Health ==="
    for container in $(podman ps --format "{{.Names}}" 2>/dev/null | grep "^pod" || true); do
        health=$(check_container_health "$container")
        if [ "$health" = "healthy" ]; then
            echo "✓ $container: healthy"
        elif [ "$health" = "unhealthy" ]; then
            echo "✗ $container: unhealthy"
        else
            echo "○ $container: $health"
        fi
    done
    
    echo ""
    echo "=== Service Connectivity ==="
    for service in "${!POD_PORTS[@]}"; do
        port=${POD_PORTS[$service]}
        status=$(check_service localhost "$port" "$service")
        
        if [ "$status" = "UP" ]; then
            echo "✓ $service:$port"
        else
            echo "✗ $service:$port"
        fi
    done
    
    echo ""
    echo "=== Resource Usage ==="
    podman stats --no-stream --format "table {{.Name}}\t{{.CPU}}\t{{.MEM}}" 2>/dev/null | head -10 || true
    
    echo ""
    echo "=== Volumes ==="
    podman volume ls --format "table {{.Name}}\t{{.Driver}}" | grep "^pod" || true
    
    echo ""
    echo "=== Networks ==="
    podman network ls --format "table {{.Name}}\t{{.Driver}}" | grep -E "pod[0-9]" || true
}

main() {
    if [ "$JSON_OUTPUT" = true ]; then
        health_check_json
    elif [ "$VERBOSE" = true ]; then
        health_check_verbose
    else
        echo "=== Health Check Summary ==="
        echo ""
        
        local total_pods=0
        local running_pods=0
        
        for pod in pods/*/; do
            pod_name=$(basename "$pod")
            ((total_pods++))
            
            status=$(check_pod "$pod_name")
            
            if [ "$status" = "RUNNING" ]; then
                ((running_pods++))
                echo "✓ $pod_name"
            else
                echo "✗ $pod_name ($status)"
            fi
        done
        
        echo ""
        echo "PODs: $running_pods / $total_pods running"
        
        local total_containers=$(podman ps --format "{{.Names}}" 2>/dev/null | grep "^pod" | wc -l)
        echo "Containers: $total_containers running"
        
        if [ $running_pods -eq $total_pods ]; then
            echo ""
            echo "All systems operational ✓"
            exit 0
        else
            echo ""
            echo "Some PODs are not running. Use --verbose for details."
            exit 1
        fi
    fi
}

main "$@"