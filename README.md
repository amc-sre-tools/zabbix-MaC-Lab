# Zabbix Testing Environment - Zabbix-MaC-Lab

Ambiente de pruebas multi-POD con Podman Compose, OpenBao y servicios asociados para testing de migración Zabbix.

## Tabla de Contenidos

1. [Descripción](#descripción)
2. [Arquitectura PODs](#arquitectura-pods)
3. [Zabbix Agents y Monitoreo](#zabbix-agents-y-monitoreo)
4. [Requisitos](#requisitos)
5. [Estructura del Proyecto](#estructura-del-proyecto)
6. [Inicio Rápido](#inicio-rápido)
7. [Scripts de Inicialización](#scripts-de-inicialización)
8. [Credenciales y Secrets](#credenciales-y-secrets)
9. [PODs Detallados](#pods-detallados)
10. [Mantenimiento](#mantenimiento)
11. [Solución de Problemas](#solución-de-problemas)

---

## Descripción

Este proyecto configura un ambiente de pruebas integral para Zabbix con arquitectura multi-POD:

- **5 PODs especializados**: CI/CD, Monitoring, Services, Observability, Provisioning
- **Gestión de secretos**: OpenBao (KV v2)
- **Container Engine**: Podman 4.0+ (no Docker)
- **Testing**: Zabbix 6.0 LTS, 7.0, 7.4 LTS para migración
- **Monitoreo**: Zabbix Agents en todos los PODs
- **Observabilidad**: Prometheus, Grafana, Elasticsearch, OTel
- **IaC**: Terraform + Ansible

---

## Arquitectura PODs

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ZABBIX TESTING ENVIRONMENT                       │
│                     5 PODs with Podman                             │
│                     Timezone: America/Bogota                        │
├─────────────────────────────────────────────────────────────────────┤

┌─────────────────────────────────────────────────────────────────────┐
│ POD1: CI/CD + DevSecOps          │ Network: 10.99.10.0/24         │
├─────────────────────────────────────┴──────────────────────────────┤
│ • OpenBao (secrets)      :8200   │ • Jenkins (CI/CD)    :8080     │
│ • SonarQube (code)       :9000   │ • Trivy (scanner)    :4954      │
│ • Zabbix Agent           :10051   │                                │
│ TZ: America/Bogota                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD2: Monitoring Zabbix        │ Network: 10.99.20.0/24            │
├─────────────────────────────────────┴──────────────────────────────┤
│ • PostgreSQL (3 BDs)        :5432  │ • Zabbix 6.0 Server  :10060    │
│   - zabbix60 / zabbix70 / zabbix74 │ • Zabbix 7.0 Server  :10070    │
│ • Zabbix 6.0 Web        :8083      │ • Zabbix 7.4 Server  :10074    │
│ • Zabbix 7.0 Web        :8081      │ • Zabbix Agent      :10050     │
│ • Zabbix 7.4 Web        :8082      │                                │
│ TZ: America/Bogota                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD3: Services Demo          │ Network: 10.99.30.0/24              │
├─────────────────────────────────────┴──────────────────────────────┤
│ • MySQL               :3306     │ • Redis            :6379       │
│ • MariaDB             :3307    │ • RabbitMQ         :5672/15672   │
│ • Nginx               :80/443  │ • FastAPI          :8000        │
│ • Node Exporter       :9100   │ • Zabbix Agent     :10052       │
│ TZ: America/Bogota                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD4: Observability DORA       │ Network: 10.99.40.0/24           │
├─────────────────────────────────────┴──────────────────────────────┤
│ • Prometheus          :9090    │ • Grafana          :3000        │
│ • Alertmanager        :9093    │ • Elasticsearch    :9200        │
│ • Kibana              :5601    │ • OTel Collector   :4317/4318   │
│ • cAdvisor            :8080    │                                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ POD5: Provisioning             │ Network: 10.99.50.0/24           │
├─────────────────────────────────────┴──────────────────────────────┤
│ • Terraform           (image)   │ • Ansible          (image)      │
│ • AWS CLI             (image)  │ • Azure CLI        (image)      │
│ • GCP CLI             (image)  │ • InSpec           (image)     │
│ • Checkov             (image) │                                │
└─────────────────────────────────────────────────────────────────────┘
```

### Resumen de Servicios

| POD | Servicios | Puertos Principales |
|-----|-----------|---------------------|
| POD1 | OpenBao, Jenkins, SonarQube, Trivy, Zabbix Agent | 8200, 8080, 9000, 4954, 10051 |
| POD2 | PostgreSQL, Zabbix 6.0/7.0/7.4, Zabbix Agent | 5432, 8080-8082, 10060-10074, 10050 |
| POD3 | MySQL, Redis, RabbitMQ, Nginx, FastAPI, Node Exporter, Zabbix Agent | 3306, 6379, 5672, 80, 8000, 9100, 10052 |
| POD4 | Prometheus, Grafana, Elasticsearch, OTel | 9090, 3000, 9200, 4317 |
| POD5 | Terraform, Ansible, Cloud CLIs | N/A (tool containers) |

**Total: 40+ servicios**

---

## Zabbix Agents y Monitoreo

### Zabbix Agents Configurados

| Agent | Puerto | Red | Monitorea |
|-------|--------|-----|-----------|
| `pod2-zabbix-agent` | 10050 | pod2-monitoring-internal | POD2 (Zabbix servers) |
| `pod1-zabbix-agent` | 10051 | pod1-cicd-internal + pod2-monitoring-internal | POD1 (OpenBao, Jenkins, SonarQube, Trivy) |
| `pod3-zabbix-agent` | 10052 | pod3-services-internal + pod2-monitoring-internal | POD3 (MySQL, Redis, RabbitMQ, Nginx, FastAPI) |

### Cómo Agregar Servicios a Zabbix

1. **Agregar Host en Zabbix**:
   - Configuration → Hosts → Create Host
   - Agent interface: IP del contenedor (ej: `pod3-mysql` para MySQL)
   - Agent port: 10052 (para POD3) o 10050 (para POD2)

2. **Templates Recomendados**:
   - Linux by Zabbix agent
   - MySQL by Zabbix agent
   - PostgreSQL by Zabbix agent
   - HTTP service monitoring

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
| Docker Compose (v2) | 2.29+ |
| Python | 3.11+ |

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
│   │   ├── docker-compose.yml         # Servicios principales
│   │   ├── docker-compose.agents.yml  # Zabbix agent
│   │   ├── config/                    # Configs de servicios
│   │   └── scripts/
│   │
│   ├── pod2-monitoring-zabbix/       # Zabbix multi-versión
│   │   ├── docker-compose.yml        # Servicios Zabbix + agente
│   │   ├── config/
│   │   │   ├── zabbix-*.env          # Variables por versión
│   │   │   ├── zabbix_agentd.conf    # Config agente POD2
│   │   │   ├── zabbix_agentd_pod1.conf
│   │   │   ├── zabbix_agentd_pod3.conf
│   │   │   └── zabbix*.conf.php      # Config web por versión
│   │   ├── zabbix_templates/         # Templates Zabbix
│   │   ├── updates/                  # Updates Zabbix
│   │   └── scripts/
│   │
│   ├── pod3-services-demo/           # Servicios demo
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.agents.yml # Zabbix agent
│   │   ├── config/
│   │   └── scripts/
│   │
│   ├── pod4-observability-dora/      # Observabilidad DORA
│   └── pod5-provisioning/            # Terraform + Ansible
│
├── scripts/                           # Scripts globales
│   ├── init-all.sh                   # Inicialización completa
│   ├── init-all-passwords.sh         # Rotación de passwords
│   ├── init-secrets.sh               # Inicializar OpenBao
│   ├── load-secrets.sh               # Cargar secrets a .env
│   ├── get-secret.sh                 # Obtener secret
│   ├── health-check.sh               # Verificación de salud
│   └── backup-weekly.sh              # Backup semanal
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

### 2. Inicialización Completa (Recomendado)

```bash
# Ejecutar script de inicialización completo
# Genera passwords seguros, configura OpenBao, inicia servicios
./scripts/init-all.sh
```

### 3. Verificar estado

```bash
# Ver todos los contenedores
podman ps --format "{{.Names}}\t{{.Status}}"

# Ver agentes Zabbix
podman ps | grep zabbix-agent
```

### 4. Acceder a servicios

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| OpenBao | http://localhost:8200 | Ver en OpenBao |
| Zabbix 6.0 | http://localhost:8083 | Admin / (ver OpenBao) |
| Zabbix 7.0 | http://localhost:8081 | Admin / (ver OpenBao) |
| Zabbix 7.4 | http://localhost:8082 | Admin / (ver OpenBao) |
| Jenkins | http://localhost:8080/jenkins | admin / (ver OpenBao) |
| SonarQube | http://localhost:9000 | admin / (ver OpenBao) |

---

## Scripts de Inicialización

### init-all.sh (Principal)

Script completo que:
1. Genera passwords seguros (12+ caracteres, mayúsculas, números, especiales)
2. Almacena todos los secrets en OpenBao
3. Actualiza passwords de Zabbix vía API
4. Inicia todos los servicios
5. Configura Zabbix Agents

```bash
./scripts/init-all.sh
```

### init-all-passwords.sh

Rotación de passwords para Zabbix y SonarQube:

```bash
./scripts/init-all-passwords.sh
```

### get-secret.sh

Recuperar un secret específico:

```bash
./scripts/get-secret.sh pod2/zabbix60
```

---

## Credenciales y Secrets

### Secret Paths en OpenBao

| Path | Keys | Descripción |
|------|------|-------------|
| `secret/data/pod1/openbao` | root_token | Token root de OpenBao |
| `secret/data/pod1/jenkins` | username, password | Credenciales Jenkins |
| `secret/data/pod1/sonarqube` | username, password | Credenciales SonarQube |
| `secret/data/pod1/trivy` | db_repository | Configuración Trivy |
| `secret/data/pod2/postgresql` | postgres_user, postgres_password | Credenciales PostgreSQL |
| `secret/data/pod2/zabbix60` | username, password | Credenciales Zabbix 6.0 |
| `secret/data/pod2/zabbix70` | username, password | Credenciales Zabbix 7.0 |
| `secret/data/pod2/zabbix74` | username, password | Credenciales Zabbix 7.4 |
| `secret/data/pod3/mysql` | root_password, app_password, username, database | Credenciales MySQL |
| `secret/data/pod3/redis` | password | Password Redis |
| `secret/data/pod3/rabbitmq` | username, password | Credenciales RabbitMQ |
| `secret/data/pod3/mariadb` | root_password, database | Credenciales MariaDB |
| `secret/data/pod3/fastapi` | secret_key, api_key | Keys FastAPI |

### Recuperar Passwords

```bash
# Ver password de Zabbix 6.0
curl -s -H "X-Vault-Token: root-token-dev-only" \
  http://localhost:8200/v1/secret/data/pod2/zabbix60 | jq -r '.data.data.password'

# Ver password de SonarQube
curl -s -H "X-Vault-Token: root-token-dev-only" \
  http://localhost:8200/v1/secret/data/pod1/sonarqube | jq -r '.data.data.password'

# Ver todas las passwords
for secret in pod2/zabbix60 pod2/zabbix70 pod2/zabbix74 pod1/sonarqube pod1/jenkins; do
  echo -n "$secret: "
  curl -s -H "X-Vault-Token: root-token-dev-only" \
    "http://localhost:8200/v1/secret/data/$secret" | jq -r '.data.data.password'
done
```

---

## PODs Detallados

### POD1: CI/CD + DevSecOps

```
Services:
├── pod1-openbao       secrets management (KV v2)     :8200
├── pod1-jenkins       CI/CD orchestration            :8080
├── pod1-sonarqube     code analysis                   :9000
├── pod1-trivy         vulnerability scanner           :4954
└── pod1-zabbix-agent  monitoring agent                :10051

Red: 10.99.10.0/24
TZ: America/Bogota
```

### POD2: Monitoring Zabbix

```
Services:
├── pod2-postgresql           database (3 BDs)         :5432
│   ├── zabbix60 → Zabbix 6.0 LTS
│   ├── zabbix70 → Zabbix 7.0
│   └── zabbix74 → Zabbix 7.4 LTS
├── pod2-zabbix-server-6.0    Zabbix 6.0 LTS           :10060
├── pod2-zabbix-web-6.0       Zabbix 6.0 Web          :8083
├── pod2-zabbix-server-7.0     Zabbix 7.0               :10070
├── pod2-zabbix-web-7.0        Zabbix 7.0 Web          :8081
├── pod2-zabbix-server-7.4    Zabbix 7.4 LTS           :10074
├── pod2-zabbix-web-7.4       Zabbix 7.4 Web          :8082
└── pod2-zabbix-agent         monitoring agent        :10050

Red: 10.99.20.0/24
TZ: America/Bogota
```

### POD3: Services Demo

```
Services:
├── pod3-mysql            MySQL 8.0                    :3306
├── pod3-redis            Redis 7                       :6379
├── pod3-mariadb          MariaDB 11                    :3307
├── pod3-rabbitmq         RabbitMQ 3.13                :5672/15672
├── pod3-nginx            Nginx                         :80/443
├── pod3-fastapi          FastAPI                       :8000
├── pod3-node-exporter    Prometheus Node Exporter      :9100
└── pod3-zabbix-agent     monitoring agent             :10052

Red: 10.99.30.0/24
TZ: America/Bogota
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

# Ver logs de un servicio
podman logs pod2-zabbix-6.0-server

# Reiniciar un servicio
podman restart pod2-zabbix-agent

# Actualizar secrets en .env
./scripts/load-secrets.sh
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

### Zabbix muestra "Incorrect user name or password"

```bash
# Resetear intentos fallidos en la base de datos
podman exec pod2-monitoring-postgresql psql -U zabbix -d zabbix60 \
  -c "UPDATE users SET attempt_failed = 0, attempt_clock = 0 WHERE userid = 1;"
```

### Zabbix Agent no conecta

```bash
# Verificar logs del agente
podman logs pod1-zabbix-agent

# Verificar conectividad
podman exec pod1-zabbix-agent zabbix_get -s localhost -p 10050 -k "system.uptime"
```

### Servicios no inician

```bash
# Ver logs detallados
podman compose logs -f

# Verificar configuración
podman compose config
```

---

## Contribuir

1. Fork el repositorio
2. Crear rama (`git checkout -b feature/nueva-caracteristica`)
3. Commit cambios (`git commit -am 'Agrega nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crear Pull Request

---

## Autor

- **Nombre**: Andrés M. Correa
- **Email**: korc.dev@gmail.com
- **GitHub**: [amc-sre-tools](https://github.com/amc-sre-tools)