# Zabbix Testing Environment

Ambiente de pruebas multi-POD con Podman Compose, OpenBao y servicios asociados para testing de migración Zabbix.

## Tabla de Contenidos

1. [Descripción](#descripción)
2. [Arquitectura PODs](#arquitectura-pods)
3. [Requisitos](#requisitos)
4. [Estructura del Proyecto](#estructura-del-proyecto)
5. [Inicio Rápido](#inicio-rápido)
6. [PODs Detallados](#pods-detallados)
7. [Scripts Globales](#scripts-globales)
8. [Credenciales](#credenciales)
9. [CI/CD con Podman](#cicd-con-podman)
10. [Mantenimiento](#mantenimiento)
11. [Solución de Problemas](#solución-de-problemas)

---

## Descripción

Este proyecto configura un ambiente de pruebas integral para Zabbix con arquitectura multi-POD:

- **5 PODs especializados**: CI/CD, Monitoring, Services, Observability, Provisioning
- **Gestión de secretos**: OpenBao (KV v2)
- **Container Engine**: Podman 4.0+ (no Docker)
- **Testing**: Zabbix 6.0, 7.0, 7.4 para migración
- **Observabilidad**: Prometheus, Grafana, Elasticsearch, OTel
- **IaC**: Terraform + Ansible

---

## Arquitectura PODs

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ZABBIX TESTING ENVIRONMENT                       │
│                     5 PODs with Podman                             │
├─────────────────────────────────────────────────────────────────────┤

┌─────────────────────────────────────────────────────────────────────┐
│ POD1: CI/CD + DevSecOps          │ Network: 10.99.10.0/24         │
├─────────────────────────────────────┴──────────────────────────────┤
│ • OpenBao (secrets)      :8200   │ • Jenkins (CI/CD)    :8080     │
│ • SonarQube (code)       :9000    │ • Trivy (scanner)   :4954     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD2: Monitoring Zabbix        │ Network: 10.99.20.0/24         │
├─────────────────────────────────────┴──────────────────────────────┤
│ • PostgreSQL (3 BDs)        :5432  │ • Zabbix 6.0 Server :10060    │
│   - zabbix60 / zabbix70 / zabbix74 │ • Zabbix 7.0 Server :10070    │
│ • Zabbix 6.0 Web        :8083    │ • Zabbix 7.4 Server :10074    │
│ • Zabbix 7.0 Web        :8081    │ • Zabbix Agent    :10050      │
│ • Zabbix 7.4 Web        :8082    │                                │
│ • TZ: America/Bogota                                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD3: Services Demo          │ Network: 10.99.30.0/24           │
├─────────────────────────────────────┴──────────────────────────────┤
│ • MySQL               :3306     │ • Redis          :6379          │
│ • MariaDB             :3307    │ • RabbitMQ       :5672/15672     │
│ • Nginx               :80/443  │ • FastAPI       :8000           │
│ • Node Exporter       :9100    │                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD4: Observability DORA       │ Network: 10.99.40.0/24          │
├─────────────────────────────────────┴──────────────────────────────┤
│ • Prometheus          :9090    │ • Grafana       :3000           │
│ • Alertmanager        :9093    │ • Elasticsearch :9200           │
│ • Kibana              :5601    │ • OTel Collector:4317/4318       │
│ • cAdvisor            :8080    │                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD5: Provisioning             │ Network: 10.99.50.0/24           │
├─────────────────────────────────────┴──────────────────────────────┤
│ • Terraform           (image)   │ • Ansible        (image)         │
│ • AWS CLI             (image)   │ • Azure CLI      (image)         │
│ • GCP CLI             (image)   │ • InSpec        (image)         │
│ • Checkov             (image)   │                                │
└─────────────────────────────────────────────────────────────────────┘
```

### Resumen de Servicios

| POD | Servicios | Puertos Principales |
|-----|-----------|---------------------|
| POD1 | OpenBao, Jenkins, SonarQube, Trivy | 8200, 8080, 9000 |
| POD2 | PostgreSQL, Zabbix 6.0/7.0/7.4 | 5432, 8080-8082, 10060-10074 |
| POD3 | MySQL, Redis, RabbitMQ, Nginx, FastAPI | 3306, 6379, 5672, 80, 8000 |
| POD4 | Prometheus, Grafana, Elasticsearch, OTel | 9090, 3000, 9200, 4317 |
| POD5 | Terraform, Ansible, Cloud CLIs | N/A (tool containers) |

**Total: 37 servicios**

---

## Requisitos

### Hardware (VM UTM)

| Recurso | Valor |
|---------|-------|
| vCPU | 4 |
| RAM | 8GB |
| Disco | 70GB |
| OS | Ubuntu 24.04 LTS |

### Software

| Software | Versión |
|----------|---------|
| Podman | 4.0+ |
| Podman Compose | 4.0+ |
| Python | 3.11+ |
| Ansible | 2.14+ |

---

## Estructura del Proyecto

```
.
├── README.md                          # Este archivo
├── SPEC.md                            # Especificación técnica
├── pyproject.toml                     # Configuración pytest
├── .env.example                       # Template de variables
├── .gitignore                         # Archivos ignorados
│
├── pods/                              # Contenedores por POD
│   ├── pod1-cicd-devsecops/          # CI/CD + DevSecOps
│   │   ├── docker-compose.yml
│   │   ├── config/                   # Configs de servicios
│   │   ├── scripts/
│   │   └── data/
│   │
│   ├── pod2-monitoring-zabbix/       # Zabbix multi-versión
│   │   ├── docker-compose.yml
│   │   ├── config/
│   │   ├── scripts/
│   │   └── data/
│   │
│   ├── pod3-services-demo/           # Servicios demo
│   │   ├── docker-compose.yml
│   │   ├── config/
│   │   ├── scripts/
│   │   └── data/
│   │
│   ├── pod4-observability-dora/      # Observabilidad DORA
│   │   ├── docker-compose.yml
│   │   ├── config/
│   │   ├── scripts/
│   │   └── data/
│   │
│   └── pod5-provisioning/            # Terraform + Ansible
│       ├── docker-compose.yml
│       ├── config/
│       ├── terraform/
│       ├── ansible/
│       ├── inventory/
│       ├── inspec/
│       └── data/
│
├── scripts/                           # Scripts globales
│   ├── init-all-pods.sh              # Inicializar todos los PODs
│   ├── init-secrets.sh              # Inicializar OpenBao
│   ├── load-secrets.sh              # Cargar secrets a .env
│   ├── backup-weekly.sh             # Backup semanal
│   └── health-check.sh              # Verificación de salud
│
├── ansible/                           # Configuración VM
│   ├── inventory.ini
│   ├── ansible.cfg
│   ├── prepare-vm.yml
│   ├── setup-podman.yml
│   └── roles/
│
├── .github/
│   └── workflows/
│       ├── ci.yml                   # CI Pipeline (Podman)
│       └── cd.yml                   # CD Pipeline (Podman)
│
└── docs/
    └── diagrams/                     # Diagramas C4
```

---

## Inicio Rápido

### 1. Clonar repositorio

```bash
git clone https://github.com/amc-sre-tools/zabbix-MaC-Lab.git
cd zabbix-MaC-Lab
```

### 2. Preparar entorno

```bash
# Crear .env desde template
cp .env.example .env

# Editar .env con tus secretos
vim .env
```

### 3. Inicializar PODs

```bash
# Inicializar todos los PODs
./scripts/init-all-pods.sh

# O inicializar servicios individually
cd pods/pod1-cicd-devsecops && podman compose up -d
```

### 4. Verificar estado

```bash
# Health check rápido
./scripts/health-check.sh

# Health check detallado
./scripts/health-check.sh --verbose

# Formato JSON (para monitoring)
./scripts/health-check.sh --json
```

---

## PODs Detallados

### POD1: CI/CD + DevSecOps

```
Services:
├── pod1-openbao      secrets management (KV v2)
├── pod1-jenkins      CI/CD orchestration
├── pod1-sonarqube    code analysis
└── pod1-trivy        vulnerability scanner

Puertos: 8200 (OpenBao), 8080 (Jenkins), 9000 (SonarQube)
Red: 10.99.10.0/24
```

### POD2: Monitoring Zabbix

```
Services:
├── pod2-postgresql           database (3 BDs: zabbix60, zabbix70, zabbix74)
├── pod2-zabbix-server-6.0    Zabbix 6.0 LTS
├── pod2-zabbix-web-6.0       Zabbix 6.0 Web (config: zabbix60.conf.php)
├── pod2-zabbix-server-7.0    Zabbix 7.0
├── pod2-zabbix-web-7.0       Zabbix 7.0 Web (config: zabbix70.conf.php)
├── pod2-zabbix-server-7.4    Zabbix 7.4 LTS
├── pod2-zabbix-web-7.4       Zabbix 7.4 Web (config: zabbix74.conf.php)
└── pod2-zabbix-agent         Zabbix Agent

Bases de datos separadas por versión:
├── zabbix60 → Zabbix 6.0
├── zabbix70 → Zabbix 7.0
└── zabbix74 → Zabbix 7.4

Puertos: 5432, 8080-8082, 10060-10074
Red: 10.99.20.0/24
```

### POD3: Services Demo

```
Services:
├── pod3-mysql            MySQL 8.0
├── pod3-redis            Redis 7
├── pod3-mariadb          MariaDB 11
├── pod3-rabbitmq         RabbitMQ 3.13
├── pod3-nginx            Nginx
├── pod3-fastapi          FastAPI
└── pod3-node-exporter    Prometheus Node Exporter

Puertos: 3306, 3307, 6379, 5672, 80, 8000, 9100
Red: 10.99.30.0/24
```

### POD4: Observability DORA

```
Services:
├── pod4-prometheus       Metrics
├── pod4-alertmanager     Alerts
├── pod4-grafana          Visualization
├── pod4-elasticsearch   Logs storage
├── pod4-kibana           Logs UI
├── pod4-otel-collector   Tracing
├── pod4-cadvisor         Container metrics
└── pod4-metrics-exporter  MySQL exporter

Puertos: 9090, 9093, 3000, 9200, 5601, 4317, 8080
Red: 10.99.40.0/24
```

### POD5: Provisioning

```
Services:
├── pod5-terraform        Terraform CLI
├── pod5-ansible          Ansible Runner
├── pod5-ansible-navigator Ansible UI
├── pod5-aws-cli          AWS CLI
├── pod5-azure-cli        Azure CLI
├── pod5-gcloud-cli       GCP CLI
├── pod5-inspec           Compliance testing
├── pod5-checkov          IaC security
└── pod5-docs             Terraform docs

Red: 10.99.50.0/24
```

---

## Scripts Globales

### init-all-pods.sh

Inicializa todas las redes, verifica configs y lista servicios disponibles.

```bash
./scripts/init-all-pods.sh
```

### backup-weekly.sh

Backup semanal de volúmenes, configuraciones y redes.

```bash
# Con variables personalizadas
BACKUP_DIR=/path/to/backups ./scripts/backup-weekly.sh

# Output: back-ups semanales en /backups
```

### health-check.sh

Verifica estado de todos los PODs y servicios.

```bash
# Resumen
./scripts/health-check.sh

# Detallado
./scripts/health-check.sh --verbose

# JSON para monitoring
./scripts/health-check.sh --json
```

---

## Credenciales

> **⚠️ IMPORTANTE**: Las credenciales por defecto se proporcionan solo para instalación inicial. **Deben cambiarse inmediatamente** después del primer inicio para mantener la seguridad del sistema.

### Credenciales por Defecto

| Servicio | URL | Usuario | Contraseña | Acción Requerida |
|----------|-----|---------|------------|------------------|
| **OpenBao** | http://localhost:8200 | (root token) | `root-token-dev-only` | ✅ Cambiar en producción |
| **Jenkins** | http://localhost:8080/jenkins | admin | (ver en contenedor) | ✅ Cambiar inmediatamente |
| **SonarQube** | http://localhost:9000 | admin | `admin` | ⚠️ CAMBIAR immediately |
| **Zabbix 6.0** | http://localhost:8083 | Admin | `zabbix` | ⚠️ CAMBIAR inmediatamente |
| **Zabbix 7.0** | http://localhost:8081 | Admin | `zabbix` | ⚠️ CAMBIAR inmediatamente |
| **Zabbix 7.4** | http://localhost:8082 | Admin | `zabbix` | ⚠️ CAMBIAR inmediatamente |
| **PostgreSQL** | localhost:5432 | zabbix | (ver en .env) | ✅ Cambiar en producción |

### Cambiar Contraseñas

```bash
# Después de iniciar los contenedores, ejecutar:
./scripts/init-all-passwords.sh

# O cambiar manualmente desde la UI:
# - Zabbix: Users → Admin → Password
# - SonarQube: My Account → Security → Change Password
```

### Configurar OpenBao

```bash
# Inicializar secretos
./scripts/init-secrets.sh -t <your-token>

# Cargar a .env
./scripts/load-secrets.sh
```

### Secret Paths en OpenBao

| Path | Keys | Descripción |
|------|------|-------------|
| `secret/data/pod1/openbao` | root_token | Token root de OpenBao |
| `secret/data/pod1/jenkins` | username, password | Credenciales Jenkins |
| `secret/data/pod1/sonarqube` | username, password | Credenciales SonarQube |
| `secret/data/pod2/postgresql` | postgres_password, zabbix_password | Credenciales PostgreSQL |
| `secret/data/pod2/zabbix60` | username, password | Credenciales Zabbix 6.0 |
| `secret/data/pod2/zabbix70` | username, password | Credenciales Zabbix 7.0 |
| `secret/data/pod2/zabbix74` | username, password | Credenciales Zabbix 7.4 |

### Recuperar Passwords de OpenBao

```bash
# Ver password de Zabbix 6.0
curl -s -H "X-Vault-Token: root-token-dev-only" \
  http://localhost:8200/v1/secret/data/pod2/zabbix60 | jq -r '.data.data.password'

# Ver password de SonarQube
curl -s -H "X-Vault-Token: root-token-dev-only" \
  http://localhost:8200/v1/secret/data/pod1/sonarqube | jq -r '.data.data.password'
```

---

## CI/CD con Podman

> **Nota**: El CI/CD primario usa **Jenkins** (POD1). GitHub Actions está disponible como backup en `.github-backup/`.

### Jenkins (Primario)

El proyecto usa Jenkins en POD1 para CI/CD:

```bash
# Jenkins está en POD1
# Acceder: http://<vm-ip>:8080/jenkins

# Los pipelines están en:
# pods/pod1-cicd-devsecops/config/jenkinsfile-ci
# pods/pod1-cicd-devsecops/config/jenkinsfile-cd
```

### GitHub Actions (Backup)

ubicado en `.github-backup/workflows/`:

```bash
# Para usar GitHub Actions como backup:
mv .github-backup/workflows .github/
mv .github-backup/actions .github/
```

### Comandos Podman

```bash
# Iniciar un POD
cd pods/pod1-cicd-devsecops
podman compose up -d

# Ver servicios
podman compose ps

# Logs
podman compose logs -f

# Detener
podman compose down

# Rebuild
podman compose build --no-cache
```

---

## Mantenimiento

### Comandos útiles

```bash
# Ver todos los contenedores
podman ps --format "{{.Names}}\t{{.Status}}"

# Ver redes
podman network ls

# Ver volúmenes
podman volume ls

# Stats en tiempo real
podman stats

# Limpiar recursos no usados
podman system prune -a
```

### Backup

```bash
# Backup manual
./scripts/backup-weekly.sh

# Restaurar volumen
tar -xzf backup-file.tar.gz -C /var/lib/containers/storage/volumes/
```

---

## Solución de Problemas

### POD no inicia

```bash
# Ver logs
podman compose logs <service>

# Verificar config
podman compose config --services
```

### Problemas de red

```bash
# Ver redes existentes
podman network ls

# Recreat redes
podman network rm <network>
podman network create --subnet 10.99.x.0/24 <network>
```

### Health check fallando

```bash
# Ver detallado
./scripts/health-check.sh --verbose

# Verificar servicios específicos
curl http://localhost:<port>/health
```

---

## Contribuir

1. Fork el repositorio
2. Crear rama (`git checkout -b feature/nueva-caracteristica`)
3. Commit cambios (`git commit -am 'Agrega nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crear Pull Request

### Requisitos para PR

- [ ] Tests pasando (`pytest --cov-fail-under=85`)
- [ ] Linters pasando (`ruff check .`, `yamllint .`)
- [ ] Security scans sin vulnerabilidades críticas
- [ ] Docker-compose válido (`podman compose config`)

---

## Licencia

MIT License - Ver LICENSE para más detalles.

---

## Autor

- **Nombre**: Andrés M. Correa
- **Email**: korc.dev@gmail.com
- **GitHub**: [amc-sre-tools](https://github.com/amc-sre-tools)