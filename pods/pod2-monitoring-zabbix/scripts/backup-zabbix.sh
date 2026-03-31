#!/bin/bash
# =============================================================================
# Zabbix Backup Script for POD2
# =============================================================================
# Backup all Zabbix databases and configurations

BACKUP_DIR="/data/backups/zabbix"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== Zabbix POD2 Backup ==="

# PostgreSQL backup
echo "Backing up PostgreSQL..."
podman exec pod2-monitoring-postgresql pg_dump -U zabbix zabbix > "$BACKUP_DIR/zabbix_db_$DATE.sql"

# Compress
gzip "$BACKUP_DIR/zabbix_db_$DATE.sql"

# Keep only last 7 days
find "$BACKUP_DIR" -name "zabbix_db_*.sql.gz" -mtime +7 -delete

echo "Backup completed: zabbix_db_$DATE.sql.gz"
ls -lh "$BACKUP_DIR"