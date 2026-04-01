# SPEC: Ambiente de Pruebas Zabbix Multi-POD

## Autor

- **Nombre**: Andrés M. Correa
- **Email**: korc.dev@gmail.com

---

## 1. Visión General

| Capa | Tecnología |
|------|------------|
| **Hypervisor** | UTM 4.7.4 (QEMU) |
| **IaC VM** | Script shell + AppleScript |
| **IaC Containers** | **Podman Compose** (no Docker) |
| **Secretos** | OpenBao (KV v2) |
| **Testing** | pytest + coverage >85% |
| **Seguridad** | OWASP + Trivy + Bandit + Hadolint |
| **CI/CD** | Jenkins (POD1) - GitHub Actions (.github-backup) |
| **Code Analysis** | SonarQube |
| **Observabilidad** | Prometheus + Grafana + Elasticsearch + OTel |
| **IaC** | Terraform + Ansible |

---

## 2. Arquitectura Multi-POD

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ZABBIX TESTING ENVIRONMENT                       │
│                     5 PODs with Podman                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ POD1: CI/CD + DevSecOps         (10.99.10.0/24)            │   │
│  │ OpenBao :8200  |  Jenkins :8080  |  SonarQube :9000         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ POD2: Monitoring Zabbix       (10.99.20.0/24)              │   │
│  │ PostgreSQL :5432  |  Zabbix 6.0/7.0/7.4  |  Agent :10050   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ POD3: Services Demo         (10.99.30.0/24)                 │   │
│  │ MySQL :3306  |  Redis :6379  |  RabbitMQ :5672  | Nginx :80  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ POD4: Observability DORA      (10.99.40.0/24)              │   │
│  │ Prometheus :9090  |  Grafana :3000  |  ES :9200  | OTel     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ POD5: Provisioning          (10.99.50.0/24)                 │   │
│  │ Terraform  |  Ansible  |  AWS/Azure/GCP CLI  |  InSpec      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Arquitectura de Código (Clean Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPAS DE ARQUITECTURA                    │
├─────────────────────────────────────────────────────────────┤
│  PRESENTATION (README, SPEC.md, docs, workflows)            │
│                           ▲                                   │
│  APPLICATION (scripts/, ansible/, pods/*/docker-compose.yml) │
│                           ▲                                   │
│  DOMAIN (configs/: openbao, nginx, zabbix, prometheus)       │
│                           ▲                                   │
│  INFRASTRUCTURE (tests/, tools/, pyproject.toml)             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Recursos VM

| Recurso | Valor |
|---------|-------|
| vCPU | 4 |
| RAM | 8GB |
| Disco | 70GB |
| OS | Ubuntu 24.04 LTS |
| Usuario | `sre-ubuntu` (sudo) |

---

## 5. Esquema LVM (3 LV)

| Logical Volume | Punto de Montaje | Tamaño |
|----------------|------------------|--------|
| `lv_root` | `/` | 25GB |
| `lv_data` | `/data` | 15GB |
| `lv_logs` | `/var/log` | 10GB |

---

## 6. Redes Podman

| Red | Subred | Propósito |
|-----|--------|-----------|
| `pod1-cicd-internal` | 10.99.10.0/24 | CI/CD + DevSecOps |
| `pod2-monitoring-internal` | 10.99.20.0/24 | Zabbix + PostgreSQL |
| `pod3-services-internal` | 10.99.30.0/24 | Demo Services |
| `pod4-observability-internal` | 10.99.40.0/24 | Prometheus + Grafana |
| `pod5-provisioning-internal` | 10.99.50.0/24 | Terraform + Ansible |

---

## 7. Componentes por POD

### POD1: CI/CD + DevSecOps

| Componente | Tipo | Versión | Red | Puertos |
|------------|------|---------|-----|---------|
| OpenBao | Contenedor | latest | pod1-cicd-internal | 8200 |
| Jenkins | Contenedor | LTS | pod1-cicd-internal | 8080, 50000 |
| SonarQube | Contenedor | 10.4-community | pod1-cicd-internal | 9000 |
| PostgreSQL (SonarQube) | Contenedor | 15 | pod1-cicd-internal | 5432 |
| Trivy | Contenedor | latest | pod1-cicd-internal | 4954 |

### POD2: Monitoring Zabbix

| Componente | Tipo | Versión | Red | Puertos | Base de Datos |
|------------|------|---------|-----|---------|---------------|
| PostgreSQL | Contenedor | 15 | pod2-monitoring-internal | 5432 | 3 BDs: zabbix60, zabbix70, zabbix74 |
| Zabbix Server 6.0 | Contenedor | 6.0-latest | pod2-monitoring-internal | 10060 | zabbix60 |
| Zabbix Web 6.0 | Contenedor | 6.0-latest | pod2-monitoring-internal | 8080 | zabbix60 |
| Zabbix Server 7.0 | Contenedor | 7.0-latest | pod2-monitoring-internal | 10070 | zabbix70 |
| Zabbix Web 7.0 | Contenedor | 7.0-latest | pod2-monitoring-internal | 8081 | zabbix70 |
| Zabbix Server 7.4 | Contenedor | 7.4-latest | pod2-monitoring-internal | 10074 | zabbix74 |
| Zabbix Web 7.4 | Contenedor | 7.4-latest | pod2-monitoring-internal | 8082 | zabbix74 |
| Zabbix Agent | Contenedor | latest | pod2-monitoring-internal | 10050 | N/A |

**Configuraciones independientes por versión:**
- `config/zabbix60.conf.php` - Zabbix 6.0 Web
- `config/zabbix70.conf.php` - Zabbix 7.0 Web
- `config/zabbix74.conf.php` - Zabbix 7.4 Web
- `scripts/init-databases.sh` - Crea las 3 bases de datos

**Timezone:** America/Bogota en todos los servicios

### POD3: Services Demo

| Componente | Tipo | Versión | Red | Puertos |
|------------|------|---------|-----|---------|
| MySQL | Contenedor | 8.0 | pod3-services-internal | 3306 |
| Redis | Contenedor | 7-alpine | pod3-services-internal | 6379 |
| MariaDB | Contenedor | 11 | pod3-services-internal | 3307 |
| RabbitMQ | Contenedor | 3.13-management-alpine | pod3-services-internal | 5672, 15672 |
| Nginx | Contenedor | alpine | pod3-services-internal | 80, 443 |
| FastAPI | Contenedor | Python 3.11 | pod3-services-internal | 8000 |
| Node Exporter | Contenedor | latest | pod3-services-internal | 9100 |

### POD4: Observability DORA

| Componente | Tipo | Versión | Red | Puertos |
|------------|------|---------|-----|---------|
| Prometheus | Contenedor | latest | pod4-observability-internal | 9090 |
| Alertmanager | Contenedor | latest | pod4-observability-internal | 9093 |
| Grafana | Contenedor | latest | pod4-observability-internal | 3000 |
| Elasticsearch | Contenedor | 8.12.0 | pod4-observability-internal | 9200, 9300 |
| Kibana | Contenedor | 8.12.0 | pod4-observability-internal | 5601 |
| OTel Collector | Contenedor | contrib | pod4-observability-internal | 4317, 4318, 8888, 8889 |
| cAdvisor | Contenedor | latest | pod4-observability-internal | 8080 |
| MySQL Exporter | Contenedor | latest | pod4-observability-internal | 9104 |

### POD5: Provisioning

| Componente | Tipo | Versión | Red |
|------------|------|---------|-----|
| Terraform | Contenedor | 1.7-light | pod5-provisioning-internal |
| Ansible Runner | Contenedor | latest | pod5-provisioning-internal |
| Ansible Navigator | Contenedor | latest | pod5-provisioning-internal |
| AWS CLI | Contenedor | 2.15 | pod5-provisioning-internal |
| Azure CLI | Contenedor | latest | pod5-provisioning-internal |
| GCP CLI | Contenedor | latest | pod5-provisioning-internal |
| InSpec | Contenedor | latest | pod5-provisioning-internal |
| Checkov | Contenedor | latest | pod5-provisioning-internal |
| Terraform Docs | Contenedor | latest | pod5-provisioning-internal |

---

## 8. Secretos OpenBao

| Secret Path | Claves |
|-------------|--------|
| `secret/data/postgresql/admin` | `postgres_password`, `zabbix_password` |
| `secret/data/zabbix/credentials` | `db_user`, `db_password` |
| `secret/data/zabbix/api-keys` | `api_token` |
| `secret/data/fastapi/app` | `secret_key`, `api_key` |
| `secret/data/jenkins/credentials` | `admin_password`, `jenkins_token` |
| `secret/data/grafana` | `admin_password` |
| `secret/data/elasticsearch` | `password` |

> **Nota Importante - POD2**: PostgreSQL usa 3 bases de datos independientes para permitir pruebas de migración entre versiones de Zabbix:
> - `zabbix60` → Zabbix 6.0 LTS
> - `zabbix70` → Zabbix 7.0
> - `zabbix74` → Zabbix 7.4 LTS
> 
> El script `scripts/init-databases.sh` crea estas bases de datos automáticamente.

---

## 9. Scripts Globales

| Script | Propósito | Uso |
|--------|-----------|-----|
| `init-all-pods.sh` | Inicializa redes y verifica configs | `./scripts/init-all-pods.sh` |
| `init-secrets.sh` | Pobla OpenBao con secretos | `./scripts/init-secrets.sh -t <token>` |
| `load-secrets.sh` | Carga secretos a .env | `./scripts/load-secrets.sh` |
| `backup-weekly.sh` | Backup semanal de volúmenes | `BACKUP_DIR=/path ./scripts/backup-weekly.sh` |
| `health-check.sh` | Verifica salud de PODs | `./scripts/health-check.sh [--verbose] [--json]` |

---

## 10. GitOps y Configuración como Código

### Estructura GitOps

```
pods/
├── pod1-cicd-devsecops/
│   ├── docker-compose.yml      # Orquestación
│   ├── config/                 # Configs mounted as volumes
│   │   ├── openbao.hcl
│   │   ├── jenkinsfile-ci
│   │   ├── jenkinsfile-cd
│   │   ├── sonar-project.properties
│   │   └── .trivy.yml
│   ├── scripts/
│   └── data/
│
├── pod2-monitoring-zabbix/
│   ├── docker-compose.yml
│   ├── config/
│   │   ├── zabbix-6.0.env
│   │   ├── zabbix-7.0.env
│   │   ├── zabbix-7.4.env
│   │   ├── zabbix60.conf.php     # Config Zabbix 6.0 Web
│   │   ├── zabbix70.conf.php     # Config Zabbix 7.0 Web
│   │   ├── zabbix74.conf.php     # Config Zabbix 7.4 Web
│   │   ├── zabbix.conf.php       # (legacy - no usado)
│   │   ├── postgresql.conf
│   │   ├── zabbix_agentd.conf
│   │   └── init-databases.sh     # Crea BDs zabbix60, zabbix70, zabbix74
│   └── scripts/
│       └── backup-zabbix.sh     # Backup por versión
│
├── pod3-services-demo/
│   ├── docker-compose.yml
│   ├── config/
│   │   ├── nginx.conf
│   │   ├── default.conf
│   │   ├── mysql.cnf
│   │   └── redis.conf
│   └── scripts/
│
├── pod4-observability-dora/
│   ├── docker-compose.yml
│   ├── config/
│   │   ├── prometheus.yml
│   │   ├── alertmanager.yml
│   │   ├── prometheus_alerts.yml
│   │   ├── otel/otel-collector-config.yml
│   │   ├── grafana/provisioning/datasources/datasources.yml
│   │   ├── grafana/dashboards/pod-services.json
│   │   ├── elasticsearch/elasticsearch.yml
│   │   └── kibana/kibana.yml
│   └── scripts/
│
└── pod5-provisioning/
    ├── docker-compose.yml
    ├── config/
    │   └── ansible.cfg
    ├── terraform/
    ├── ansible/
    ├── inventory/hosts.ini
    └── inspec/
```

### Principios GitOps

1. **Todo como Código**: Todas las configs en repositorio
2. **Volumes Mounted**: Configs montados como volúmenes para GitOps replication
3. **Secrets via OpenBao**: No hardcoded passwords
4. **Branching**: main (producción), dev (desarrollo)

---

## 11. Testing y Calidad

### Cobertura

- Mínimo **85%** coverage en scripts y configs
- Tests unitarios en `tests/unit/`
- Tests de integración en `tests/integration/`
- Tests de seguridad en `tests/security/`

### Herramientas

| Herramienta | Propósito |
|-------------|-----------|
| pytest | Testing framework |
| ruff | Python linting |
| yamllint | YAML validation |
| shellcheck | Shell script validation |
| ansible-lint | Ansible validation |
| trivy | Vulnerability scanning |
| bandit | Python security |
| hadolint | Dockerfile lint |

---

## 12. CI/CD Pipeline

> **Nota**: Jenkins (POD1) es el CI/CD primario. GitHub Actions está en `.github-backup/workflows/` como backup.

### Jenkins (Primario)

Los pipelines de Jenkins están definidos en:
- `pods/pod1-cicd-devsecops/config/jenkinsfile-ci` - Pipeline CI
- `pods/pod1-cicd-devsecops/config/jenkinsfile-cd` - Pipeline CD

Funciones:
1. **Linting** - Ruff, yamllint, shellcheck, ansible-lint
2. **Security** - Trivy, Bandit, Hadolint
3. **Tests** - pytest con coverage >85%
4. **Build** - podman compose build
5. **Deploy** - podman compose up -d
6. **Verify** - health-check.sh

### GitHub Actions (Backup)

Ubicación: `.github-backup/workflows/`

Para activar:
```bash
mv .github-backup/workflows .github/
mv .github-backup/actions .github/
```

---

## 13. Backup y Recuperación

### Estrategia Weekly

- **Frecuencia**: Semanal (domingo 2 AM)
- **Retención**: 4 semanas
- **Incluye**:
  - Volúmenes de datos
  - Configuraciones de red
  - Archivos de configuración
  - Variables de entorno (encriptado recomendado)

### Restauración

```bash
# Restaurar volumen
tar -xzf <backup-file> -C /var/lib/containers/storage/volumes/

# Restaurar configuración
tar -xzf pods_config_<date>.tar.gz -C <project-root>/
```

---

## 14. Métricas DORA

El proyecto incluye configuración para metricas DORA en POD4:

| Métrica | Herramienta |
|---------|-------------|
| **Deployment Frequency** | Prometheus + Grafana |
| **Lead Time for Changes** | Prometheus + Grafana |
| **Mean Time to Recovery** | Alertmanager + Grafana |
| **Change Failure Rate** | Prometheus + Grafana |

---

## 15. Notas de Seguridad

### No Exponer

- ❌ Secrets en código (usar OpenBao)
- ❌ SSH keys en repositorio
- ❌ Passwords hardcodeados
- ❌ Tokens en logs

### Sí Implementar

- ✅ Network segmentation por POD
- ✅ Secrets via OpenBao KV v2
- ✅ Scan automático con Trivy
- ✅ .gitignore actualizado
- ✅ TLS en producción (no en dev)

---

## 16. Referencias

- [Podman Docs](https://docs.podman.io/)
- [OpenBao Docs](https://openbao.io/)
- [Zabbix Docs](https://www.zabbix.com/documentation/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Terraform Docs](https://developer.hashicorp.com/terraform)
- [Ansible Docs](https://docs.ansible.com/)