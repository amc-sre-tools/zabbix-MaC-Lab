#!/bin/bash
# =============================================================================
# Weekly Backup Script - Zabbix Testing Environment
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Weekly backup for all PODs with rotation
# Usage: ./scripts/backup-weekly.sh
# Cron: 0 2 * * 0 (Every Sunday at 2 AM)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BACKUP_DIR/backup_$DATE.log"

declare -A POD_BACKUP_PATHS=(
    ["pod1-cicd-devsecops"]="/openbao/data,/var/jenkins_home,/opt/sonarqube"
    ["pod2-monitoring-zabbix"]="/var/lib/postgresql/data,/var/lib/zabbix"
    ["pod3-services-demo"]="/var/lib/mysql,/data,/var/lib/rabbitmq"
    ["pod4-observability-dora"]="/prometheus,/var/lib/grafana,/usr/share/elasticsearch/data"
    ["pod5-provisioning"]="/workspace"
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

create_backup_dir() {
    log "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
}

backup_volumes() {
    log "Backing up Podman volumes..."
    
    for pod in "${!POD_BACKUP_PATHS[@]}"; do
        log "  Backing up $pod..."
        
        volumes=$(podman volume ls -q | grep "^pod" | grep "${pod#pod}" || true)
        
        for volume in $volumes; do
            if podman volume inspect "$volume" &>/dev/null; then
                backup_file="$BACKUP_DIR/${pod}_${volume}_${DATE}.tar.gz"
                log "    Compressing volume: $volume -> $backup_file"
                
                podman run --rm \
                    -v "$volume":/source:ro \
                    -v "$BACKUP_DIR":/backup:rw \
                    alpine:latest \
                    tar czf "/backup/$(basename $backup_file)" -C /source . \
                    2>/dev/null || log "    Warning: Failed to backup $volume"
            fi
        done
    done
}

backup_podman_networks() {
    log "Backing up Podman network configurations..."
    
    network_config_file="$BACKUP_DIR/networks_${DATE}.json"
    podman network inspect $(podman network ls -q) > "$network_config_file" 2>/dev/null || true
    log "  Network config saved to: $network_config_file"
}

backup_pod_configs() {
    log "Backing up POD configurations..."
    
    config_backup="$BACKUP_DIR/pods_config_${DATE}.tar.gz"
    tar czf "$config_backup" -C "$PROJECT_ROOT" pods/ 2>/dev/null || true
    log "  POD configs saved to: $config_backup"
}

backup_environment() {
    log "Backing up environment files..."
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        env_backup="$BACKUP_DIR/env_${DATE}.tar.gz"
        tar czf "$env_backup" -C "$PROJECT_ROOT" .env 2>/dev/null || true
        log "  Environment (encrypted recommended) saved to: $env_backup"
    fi
}

rotate_old_backups() {
    log "Rotating old backups (keeping last 4 weeks)..."
    
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +28 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.json" -mtime +28 -delete 2>/dev/null || true
    
    local backup_count=$(find "$BACKUP_DIR" -type f | wc -l)
    log "  Total backups after rotation: $backup_count"
}

verify_backups() {
    log "Verifying backups..."
    
    local failed=0
    
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup" ]; then
            if tar tzf "$backup" &>/dev/null; then
                log "  ✓ $(basename $backup) is valid"
            else
                log "  ✗ $(basename $backup) is corrupted"
                ((failed++))
            fi
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log "Warning: $failed backup(s) failed verification"
    fi
}

show_summary() {
    log "=== Backup Summary ==="
    log "Date: $DATE"
    log "Backup Directory: $BACKUP_DIR"
    log ""
    log "Recent backups:"
    ls -lh "$BACKUP_DIR" | tail -10 | awk '{print "  " $9 " (" $5 ")"}'
    log ""
    log "To restore a backup:"
    log "  tar -xzf <backup-file> -C /var/lib/containers/storage/volumes/"
}

main() {
    log "=== Starting Weekly Backup ==="
    
    create_backup_dir
    backup_volumes
    backup_podman_networks
    backup_pod_configs
    backup_environment
    rotate_old_backups
    verify_backups
    show_summary
    
    log "=== Backup Complete ==="
    log "Log file: $LOG_FILE"
}

main "$@"