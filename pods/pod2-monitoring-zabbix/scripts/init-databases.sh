#!/bin/bash
# =============================================================================
# PostgreSQL init script for POD2 - Creates separate databases per Zabbix version
# =============================================================================

set -e

export PGDATA="/var/lib/postgresql/data/pgdata"
export TZ="America/Bogota"

POSTGRES_USER="${POSTGRES_USER:-zabbix}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-zabbix_pwd}"

echo "=== Creating Zabbix databases per version ==="
echo "Timezone: $TZ"

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "CREATE DATABASE zabbix60;" || echo "Database zabbix60 already exists"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "CREATE DATABASE zabbix70;" || echo "Database zabbix70 already exists"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "CREATE DATABASE zabbix74;" || echo "Database zabbix74 already exists"

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "\l"

echo "=== Databases created successfully ==="