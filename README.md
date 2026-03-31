# Zabbix Testing Environment

Ambiente de pruebas multi-versión de Zabbix con Podman Compose, OpenBao y servicios asociados.

## Tabla de Contenidos

1. [Descripción](#descripción)
2. [Arquitectura](#arquitectura)
3. [Arquitectura de Código](#arquitectura-de-código)
4. [Requisitos](#requisitos)
5. [Estructura del Proyecto](#estructura-del-proyecto)
6. [Inicio Rápido](#inicio-rápido)
7. [Testing y Calidad](#testing-y-calidad)
8. [Seguridad DevSecOps](#seguridad-devsecops)
9. [Análisis de Código](#análisis-de-código)
10. [CI/CD](#cicd)
11. [Servicios](#servicios)
12. [Credenciales](#credenciales)
13. [Diagramas C4](#diagramas-c4)
14. [Mantenimiento](#mantenimiento)
15. [Solución de Problemas](#solución-de-problemas)
16. [Contribuir](#contribuir)

---

## Descripción

Este proyecto configura un ambiente de pruebas local para Zabbix con las siguientes características:

- **3 versiones de Zabbix**: 6.0, 7.0, 7.4 ejecutándose simultáneamente
- **Gestión de secretos**: OpenBao (KV v2)
- **API de simulación**: FastAPI con logs JSON estructurados
- **Proxy reverso**: Nginx para acceso unificado
- **Base de datos**: PostgreSQL 15
- **Quality Assurance**: Testing TDD, cobertura >85%
- **Seguridad**: OWASP compliance, scanning automático
- **CI/CD**: GitHub Actions para integración y despliegue continuos

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MAC CON UTM 4.7.4                             │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐  │
│   │         Ubuntu Server 24.04 LTS VM (4 vCPU, 8GB, 70GB)      │  │
│   │                                                              │  │
│   │  ┌────────────────────────────────────────────────────────┐ │  │
│   │  │              Podman Compose Engine                     │ │  │
│   │  │                                                         │ │  │
│   │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │  │
│   │  │  │  OpenBao    │  │ PostgreSQL  │  │    Nginx    │    │ │  │
│   │  │  │   :8200     │  │   :5432     │  │  :80, :443  │    │ │  │
│   │  │  └──────────────┘  └──────────────┘  └──────────────┘    │ │  │
│   │  │                                                         │ │  │
│   │  │  ┌──────────────────────────────────────────────────┐  │ │  │
│   │  │  │              Zabbix Servers                       │  │ │  │
│   │  │  │  • 6.0 (server:10060, web:8080)                  │  │ │  │
│   │  │  │  • 7.0 (server:10070, web:8081)                  │  │ │  │
│   │  │  │  • 7.4 (server:10074, web:8082)                  │  │ │  │
│   │  │  └──────────────────────────────────────────────────┘  │ │  │
│   │  │                                                         │ │  │
│   │  │  ┌──────────────────────────────────────────────────┐  │ │  │
│   │  │  │              FastAPI (simulación)                 │  │ │  │
│   │  │  │  • :8000 • logs JSON cada 60s                     │  │ │  │
│   │  │  └──────────────────────────────────────────────────┘  │ │  │
│   │  │                                                         │ │  │
│   │  │  ═══════════════════════════════════════════════════    │ │  │
│   │  │              LVM Storage (70GB)                       │ │  │
│   │  │  • /data (15GB)  • /var/lib/containers (20GB)          │ │  │
│   │  │  • /var/log (10GB)                                    │ │  │
│   │  └────────────────────────────────────────────────────────┘ │  │
│   └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Redes Podman

| Red | Subred | Propósito |
|-----|--------|-----------|
| `bridge-zabbix` | 10.88.10.0/24 | Servidores Zabbix |
| `bridge-servicios` | 10.88.20.0/24 | PostgreSQL, Nginx, FastAPI |
| `bridge-secrets` | 10.88.30.0/24 | OpenBao |

---

## Arquitectura de Código

El proyecto sigue una estructura de **Arquitectura Limpia (Clean Architecture)** con separación de responsabilidades:

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPAS DE ARQUITECTURA                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PRESENTATION (Capa de Presentación)                  │   │
│  │  ├── README.md                                       │   │
│  │  ├── docs/diagrams/                                  │   │
│  │  └── .github/workflows/                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ▲                                 │
│                           │                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  APPLICATION (Capa de Aplicación)                   │   │
│  │  ├── scripts/                                        │   │
│  │  ├── ansible/                                       │   │
│  │  └── docker-compose.yml                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ▲                                 │
│                           │                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  DOMAIN (Capa de Dominio)                           │   │
│  │  ├── configs/fastapi/main.py                        │   │
│  │  ├── configs/nginx/nginx.conf                      │   │
│  │  └── configs/openbao/config.hcl                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ▲                                 │
│                           │                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  INFRASTRUCTURE (Capa de Infraestructura)           │   │
│  │  ├── tests/                                         │   │
│  │  ├── tools/                                         │   │
│  │  └── pyproject.toml                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Principios Aplicados

- **Dependency Inversion**: Las capas superiores no dependen de las inferiores
- **Single Responsibility**: Cada componente tiene una responsabilidad clara
- **Separation of Concerns**: Scripts, configs y tests están separados
- **DRY (Don't Repeat Yourself)**: Configuraciones centralizadas

---

## Requisitos

### Hardware VM (UTM)

| Recurso | Valor |
|---------|-------|
| vCPU | 4 |
| RAM | 8GB |
| Disco | 70GB |
| OS | Ubuntu 24.04 LTS |

### Software

| Software | Versión Mínima |
|----------|----------------|
| UTM | 4.7.4 |
| Podman | 4.0+ |
| Ansible | 2.14+ |
| Python | 3.11+ |

---

## Estructura del Proyecto

```
.
├── README.md                          # Este archivo
├── SPEC.md                            # Especificación técnica
├── pyproject.toml                     # Configuración pytest + coverage
├── sonar-project.properties           # Configuración SonarQube
├── docker-compose.yml                 # Orquestación de contenedores
├── docker-compose.sonarqube.yml       # SonarQube
├── .gitignore                         # Archivos ignorados
│
├── scripts/                           # Capa de Aplicación
│   ├── create-utm-vm.sh              # Crear VM en UTM
│   ├── cloud-init/
│   │   └── user-data.yml             # Cloud-init config
│   ├── init-secrets.sh               # Inicializar OpenBao
│   └── health-check.sh               # Verificar servicios
│
├── ansible/                           # Configuración VM
│   ├── inventory.ini
│   ├── ansible.cfg
│   ├── prepare-vm.yml
│   ├── setup-podman.yml
│   └── roles/
│       ├── lvm/
│       │   └── tasks/main.yml
│       └── podman/
│           ├── tasks/main.yml
│           └── templates/
│               └── storage.conf.j2
│
├── configs/                           # Capa de Dominio
│   ├── openbao/
│   │   └── config.hcl
│   ├── nginx/
│   │   └── nginx.conf
│   └── fastapi/
│       ├── Dockerfile
│       ├── main.py
│       └── requirements.txt
│
├── tests/                             # Capa de Infraestructura
│   ├── unit/
│   │   └── test_scripts.py           # Tests unitarios
│   ├── integration/
│   │   └── test_services.py         # Tests de integración
│   ├── security/
│   │   └── test_security.py        # Tests de seguridad
│   └── requirements.txt
│
├── tools/                             # Herramientas
│   ├── linters/
│   │   └── setup-linters.sh
│   └── security/
│       └── setup-security-tools.sh
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # CI Pipeline
│   │   └── cd.yml                    # CD Pipeline
│   └── actions/
│       ├── qa-skill.yml              # AI: Testing
│       └── deploy-skill.yml           # AI: Deployment
│
└── docs/
    └── diagrams/                      # Diagramas C4
        ├── c1-context.drawio
        ├── c2-container.drawio
        ├── c3-component.drawio
        └── c4-code.drawio
```

---

## Inicio Rápido

### Paso 1: Clonar el Repositorio

```bash
git clone https://github.com/<your-repo>/zabbix-testing.git
cd zabbix-testing
```

### Paso 2: Instalar Herramientas

```bash
# Linters
chmod +x tools/linters/setup-linters.sh
./tools/linters/setup-linters.sh

# Security tools
chmod +x tools/security/setup-security-tools.sh
./tools/security/setup-security-tools.sh
```

### Paso 3: Crear la VM en UTM

```bash
cd scripts
chmod +x create-utm-vm.sh
./create-utm-vm.sh
```

### Paso 4: Provisioning de la VM

```bash
cd ansible
ansible-playbook -i inventory.ini prepare-vm.yml
ansible-playbook -i inventory.ini setup-podman.yml
```

### Paso 5: Desplegar Contenedores

```bash
podman compose up -d
```

### Paso 6: Verificar Servicios

```bash
./scripts/health-check.sh
```

---

## Testing y Calidad

### Ejecución de Tests

```bash
# Todos los tests con coverage
pytest tests/ --cov=scripts --cov=configs --cov-fail-under=85 -v

# Tests unitarios
pytest tests/unit/ -v

# Tests de integración
pytest tests/integration/ -m integration -v

# Tests de seguridad
pytest tests/security/ -m security -v
```

### Cobertura

El proyecto requiere un mínimo de **85% de cobertura** en scripts y configs:

```bash
# Generar reporte HTML
pytest --cov=scripts --cov=configs --cov-report=html

# Generar reporte XML (para CI/CD)
pytest --cov=scripts --cov=configs --cov-report=xml
```

### Marcadores de Tests

| Marcador | Descripción |
|----------|-------------|
| `@pytest.mark.unit` | Tests unitarios |
| `@pytest.mark.integration` | Tests de integración |
| `@pytest.mark.security` | Tests de seguridad |
| `@pytest.mark.slow` | Tests que toman más de 5 segundos |

---

## Seguridad DevSecOps

### Herramientas de Seguridad

| Herramienta | Propósito | Comando |
|-------------|-----------|---------|
| **Trivy** | Vulnerability scanner | `trivy fs .` |
| **Bandit** | Python security | `bandit -r configs/fastapi` |
| **Hadolint** | Dockerfile lint | `hadolint configs/fastapi/Dockerfile` |
| **Semgrep** | Static analysis | `semgrep --config=auto .` |
| **Checkov** | IaC security | `checkov -d .` |

### OWASP Compliance

- ✅ Secret management con OpenBao
- ✅ Container security scanning
- ✅ Dependency vulnerability scanning
- ✅ Infrastructure as Code validation
- ✅ Network segmentation (3 redes separadas)
- ✅ No hardcoded credentials

### Ejecución de Security Scans

```bash
# Scan completo
trivy fs --security-checks vuln,config .
bandit -r configs/fastapi
hadolint configs/fastapi/Dockerfile

# Todo en uno
chmod +x tools/security/setup-security-tools.sh
./tools/security/setup-security-tools.sh
```

---

## Análisis de Código

### SonarQube

Para análisis de código con SonarQube:

```bash
# Iniciar SonarQube
podman compose -f docker-compose.sonarqube.yml up -d

# Esperar a que esté listo (~60s)
# Acceder a http://localhost:9000

# Credenciales por defecto
# Usuario: admin
# Contraseña: admin

# Ejecutar análisis
sonar-scanner -Dsonar.projectKey=zabbix-testing \
  -Dsonar.sources=scripts,configs \
  -Dsonar.host.url=http://localhost:9000
```

### Configuración

El archivo `sonar-project.properties` contiene:

- Project key: `zabbix-testing-environment`
- Fuentes: scripts, configs, ansible
- Cobertura: coverage.xml
- Python version: 3.11

---

## CI/CD

### GitHub Actions

#### Pipeline de CI (ci.yml)

Se ejecuta en cada push y pull request:

1. **Linting** - Ruff, yamllint, shellcheck, ansible-lint
2. **Security Scanning** - Trivy, Bandit, Hadolint
3. **Unit Tests** - pytest con coverage >85%
4. **Integration Tests** - Tests de servicios
5. **Build Containers** - Construcción de imágenes

#### Pipeline de CD (cd.yml)

Se ejecuta al hacer merge a main:

1. **Deploy to VM** - Ansible provisioning
2. **Deploy Containers** - podman compose
3. **Deploy SonarQube** - Análisis de código

### Usage

```bash
# Ejecución manual
gh workflow run ci.yml
gh workflow run cd.yml

# Ver resultados
gh run view
```

---

## Servicios

### Puertos de Acceso

| Servicio | Puerto | URL | Descripción |
|----------|--------|-----|-------------|
| OpenBao | 8200 | http://localhost:8200 | Gestión de secretos |
| Zabbix 6.0 Web | 8080 | http://localhost:8080 | Interfaz Zabbix 6.0 |
| Zabbix 7.0 Web | 8081 | http://localhost:8081 | Interfaz Zabbix 7.0 |
| Zabbix 7.4 Web | 8082 | http://localhost:8082 | Interfaz Zabbix 7.4 |
| Zabbix 6.0 Server | 10060 | localhost:10060 | Server Zabbix 6.0 |
| Zabbix 7.0 Server | 10070 | localhost:10070 | Server Zabbix 7.0 |
| Zabbix 7.4 Server | 10074 | localhost:10074 | Server Zabbix 7.4 |
| Nginx | 80 | http://localhost:80 | Proxy reverso |
| FastAPI | 8000 | http://localhost:8000 | API de simulación |
| PostgreSQL | 5432 | localhost:5432 | Base de datos |
| SonarQube | 9000 | http://localhost:9000 | Análisis de código |

### Credenciales por Defecto

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| Zabbix | Admin | zabbix |
| PostgreSQL | zabbix | zabbix_password |
| OpenBao | root | root-token-dev-only (dev) |
| SonarQube | admin | admin |

---

## Credenciales

### Almacenamiento Seguro

Las credenciales se almacenan en OpenBao (KV v2):

| Secret Path | Claves |
|-------------|--------|
| `secret/data/postgresql/admin` | `postgres_password`, `zabbix_password` |
| `secret/data/zabbix/credentials` | `db_user`, `db_password` |
| `secret/data/zabbix/api-keys` | `api_token` |
| `secret/data/fastapi/app` | `secret_key`, `api_key` |
| `secret/data/nginx/ssl` | `cert`, `key`, `dhparam` |

### Inicializar Secretos

```bash
./scripts/init-secrets.sh
```

---

## Diagramas C4

El proyecto incluye 4 niveles de diagramas C4 en formato draw.io:

| Diagrama | Archivo | Descripción |
|---------|---------|-------------|
| **C1 - Context** | `docs/diagrams/c1-context.drawio` | Visión general del sistema |
| **C2 - Container** | `docs/diagrams/c2-container.drawio` | Contenedores y relaciones |
| **C3 - Component** | `docs/diagrams/c3-component.drawio` | Componentes internos |
| **C4 - Code** | `docs/diagrams/c4-code.drawio` | Estructura de código |

Para visualizar los diagramas, ábrelos en [draw.io](https://app.diagrams.net/).

---

## Mantenimiento

### Comandos Útiles

```bash
# Iniciar servicios
podman compose up -d

# Detener servicios
podman compose down

# Reiniciar un servicio
podman compose restart zabbix-6.0

# Ver logs
podman compose logs -f

# Actualizar contenedores
podman compose pull
podman compose up -d

# Ver uso de recursos
podman stats

# Limpiar recursos
podman system prune -a
```

### Backups

```bash
# Backup de PostgreSQL
podman exec postgresql pg_dump -U zabbix zabbix > backup_$(date +%Y%m%d).sql

# Backup de volúmenes
podman volume ls
podman volume save postgresql-data -o postgresql-data.tar
```

---

## Solución de Problemas

### La VM no inicia

1. Verificar que UTM esté instalado correctamente
2. Revisar la configuración en `scripts/create-utm-vm.sh`
3. Verificar que la imagen de Ubuntu se descargó correctamente

### Los contenedores no inician

```bash
# Ver logs
podman compose logs <servicio>
podman compose ps
```

### No se puede conectar a OpenBao

```bash
# Verificar contenedor
podman ps | grep openbao

# Verificar puerto
ss -tlnp | grep 8200
```

### Problemas de red

```bash
# Ver redes
podman network ls

# Recrea las redes
podman compose down
podman compose up -d
```

---

## AI Agent Skills

El proyecto incluye skills para agentes AI que facilitan el trabajo:

### QA Skill

```bash
# Run tests via skill
github actions run qa-skill.yml --arg "command=run-all-tests"
```

### Deployment Skill

```bash
# Deploy via skill
github actions run deploy-skill.yml --arg "command=deploy-all"
```

---

## Contribuir

1. Fork el repositorio
2. Crea una rama (`git checkout -b feature/nueva-caracteristica`)
3. Commit tus cambios (`git commit -am 'Agrega nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crea un Pull Request

### Requisitos para PR

- [ ] Tests pasando (`pytest --cov-fail-under=85`)
- [ ] Linters pasando (`ruff check .`, `yamllint .`)
- [ ] Security scans sin vulnerabilidades críticas
- [ ] Coverage >85%

---

## Licencia

MIT License - Ver LICENSE para más detalles.

---

## Autor

- **Nombre**: Andrés M. Correa
- **Email**: korc.dev@gmail.com
- **GitHub**: [tu-usuario](https://github.com/tu-usuario)
