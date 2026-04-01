#!/bin/bash

# =============================================================================
# SonarQube Password Initialization Script
# =============================================================================
# Changes the default admin password on first SonarQube startup
# Usage: Run after SonarQube is fully started
# =============================================================================

set -e

SONAR_URL="${SONARQUBE_URL:-http://localhost:9000}"
NEW_PASSWORD="${SONARQUBE_ADMIN_PASSWORD:-}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-admin}"

wait_for_sonarqube() {
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for SonarQube..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$SONAR_URL/api/system/status" > /dev/null 2>&1; then
            local status
            status=$(curl -sf "$SONAR_URL/api/system/status" | jq -r '.status' 2>/dev/null)
            if [ "$status" = "UP" ]; then
                echo "SonarQube is UP"
                return 0
            fi
        fi
        echo "  Attempt $attempt/$max_attempts..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "Timeout waiting for SonarQube"
    return 1
}

init_sonarqube_password() {
    if [ -z "$NEW_PASSWORD" ]; then
        echo "No SONARQUBE_ADMIN_PASSWORD set, skipping password change"
        return 0
    fi
    
    echo "Initializing SonarQube admin password..."
    
    local attempt=1
    local max_attempts=10
    
    while [ $attempt -le $max_attempts ]; do
        local change_response
        change_response=$(curl -sf -X POST "$SONAR_URL/api/users/change_password" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "login=admin&previousPassword=$DEFAULT_PASSWORD&password=$NEW_PASSWORD" 2>/dev/null)
        
        if [ -z "$change_response" ]; then
            local verify_response
            verify_response=$(curl -sf "$SONAR_URL/api/authentication/validate" \
                -H "Authorization: Basic $(echo -n admin:$NEW_PASSWORD | base64)" 2>/dev/null)
            
            local is_valid
            is_valid=$(echo "$verify_response" | jq -r '.valid' 2>/dev/null)
            
            if [ "$is_valid" = "true" ]; then
                echo "Password updated successfully for SonarQube"
                return 0
            fi
        fi
        
        echo "  Attempt $attempt/$max_attempts - retrying..."
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "Failed to update SonarQube password"
    return 1
}

echo "=== SonarQube Password Initialization ==="
wait_for_sonarqube
init_sonarqube_password
echo "=== Initialization Complete ==="