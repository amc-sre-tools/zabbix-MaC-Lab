#!/bin/bash
# =============================================================================
# Zabbix Backup Script for POD2
# =============================================================================
# Backup all Zabbix databases (per version) and configurations

BACKUP_DIR="/data/backups/zabbix"
DATE=$(date +%Y%m%d_%H%M%S)
POSTGRES_USER="${POSTGRES_USER:-zabbix}"

mkdir -p "$BACKUP_DIR"

echo "=== Zabbix POD2 Backup ==="

DATABASES=("zabbix60" "zabbix70" "zabbix74")

for DB in "${DATABASES[@]}"; do
    echo "Backing up $DB..."
    podman exec pod2-monitoring-postgresql pg_dump -U "$POSTGRES_USER" "$DB" > "$BACKUP_DIR/${DB}_$DATE.sql"
    gzip "$BACKUP_DIR/${DB}_$DATE.sql"
    echo "Backup completed: ${DB}_$DATE.sql.gz"
done

find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete

echo "=== Backup Summary ==="
ls -lh "$BACKUP_DIR"