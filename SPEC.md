# SPEC: Ambiente de Pruebas Zabbix Multi-Versión

## Autor

- **Nombre**: Andrés M. Correa
- **Email**: korc.dev@gmail.com

---

## 1. Visión General

| Capa | Tecnología |
|------|------------|
| **Hypervisor** | UTM 4.7.4 (QEMU) |
| **IaC VM** | Script shell + AppleScript |
| **IaC Containers** | Podman Compose |
| **Secretos** | OpenBao (KV v2) |
| **Testing** | pytest + coverage >85% |
| **Seguridad** | OWASP + Trivy + Bandit + Hadolint |
| **CI/CD** | GitHub Actions |
| **Code Analysis** | SonarQube |

---

## 2. Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MAC CON UTM 4.7.4                             │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐  │
│   │         Ubuntu Server 24.04 LTS VM (4 vCPU, 8GB, 70GB)      │  │
│   │                                                              │  │
│   │  ┌─────────┐  ┌──────────┐  ┌──────────────────┐          │  │
│   │  │   LVM   │  │  Podman  │  │     OpenBao      │          │  │
│   │  │  3 LV   │  │ Compose  │  │     (KV v2)      │          │  │
│   │  └─────────┘  └──────────┘  └──────────────────┘          │  │
│   │                                                              │  │
│   │  Zabbix 6.0  •  Zabbix 7.0  •  Zabbix 7.4                   │  │
│   │  PostgreSQL  •  Nginx  •  FastAPI (logs JSON)                │  │
│   └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Arquitectura de Código (Clean Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPAS DE ARQUITECTURA                    │
├─────────────────────────────────────────────────────────────┤
│  PRESENTATION (README, docs, workflows)                       │
│                           ▲                                   │
│  APPLICATION (scripts, ansible, docker-compose)              │
│                           ▲                                   │
│  DOMAIN (configs: fastapi, nginx, openbao)                   │
│                           ▲                                   │
│  INFRASTRUCTURE (tests, tools, pyproject.toml)               │
└─────────────────────────────────────────────────────────────┘
```

### Principios

- **Dependency Inversion**: Capas superiores no dependen de inferiores
- **Single Responsibility**: Cada componente responsabilidad clara
- **Separation of Concerns**: Scripts, configs, tests separados
- **DRY**: Configuraciones centralizadas

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
| `bridge-zabbix` | 10.88.10.0/24 | Servidores Zabbix |
| `bridge-servicios` | 10.88.20.0/24 | PostgreSQL, Nginx, FastAPI |
| `bridge-secrets` | 10.88.30.0/24 | OpenBao |

---

## 7. Componentes

| Componente | Tipo | Versión | Red | Puertos |
|------------|------|---------|-----|---------|
| OpenBao | Contenedor | 2.5.x | bridge-secrets | 8200 |
| Zabbix 6.0 | Contenedor | 6.0-latest | bridge-zabbix | 10060, 8080 |
| Zabbix 7.0 | Contenedor | 7.0-latest | bridge-zabbix | 10070, 8081 |
| Zabbix 7.4 | Contenedor | 7.4-latest | bridge-zabbix | 10074, 8082 |
| PostgreSQL | Contenedor | 15 | bridge-servicios | 5432 |
| Nginx | Contenedor | latest | bridge-servicios | 80, 443 |
| FastAPI | Contenedor | Python 3.11 | bridge-servicios | 8000 |
| SonarQube | Contenedor | 10.4 | bridge-servicios | 9000 |

---

## 8. Secretos OpenBao

| Secret Path | Claves |
|-------------|--------|
| `secret/data/postgresql/admin` | `postgres_password`, `zabbix_password` |
| `secret/data/zabbix/credentials` | `db_password`, `db_user` |
| `secret/data/zabbix/api-keys` | `api_token` |
| `secret/data/fastapi/app` | `secret_key`, `api_key` |
| `secret/data/nginx/ssl` | `cert`, `key`, `dhparam` |

---

## 9. Testing y Calidad (TDD)

### Estructura de Tests

```
tests/
├── unit/
│   └── test_scripts.py           # Tests unitarios
├── integration/
│   └── test_services.py         # Tests de integración
├── security/
│   └── test_security.py         # Tests de seguridad
└── requirements.txt              # Dependencias de test
```

### Cobertura Requerida

| Objetivo | Mínimo |
|----------|--------|
| Cobertura total | > 85% |
| Scripts | 100% |
| Configs | 80% |

### Marcadores

| Marcador | Descripción |
|----------|-------------|
| `@pytest.mark.unit` | Tests unitarios |
| `@pytest.mark.integration` | Tests de integración |
| `@pytest.mark.security` | Tests de seguridad |
| `@pytest.mark.slow` | Tests > 5 segundos |

---

## 10. Seguridad DevSecOps

### Herramientas OWASP

| Herramienta | Propósito | Instalación |
|-------------|-----------|--------------|
| **Trivy** | Vulnerability scanning | `tools/security/setup-security-tools.sh` |
| **Bandit** | Python security | `pip install bandit` |
| **Hadolint** | Dockerfile lint | `tools/security/setup-security-tools.sh` |
| **Semgrep** | Static analysis | `pip install semgrep` |
| **Checkov** | IaC security | `pip install checkov` |

### Linters

| Herramienta | Propósito |
|-------------|-----------|
| **Ruff** | Python linter |
| **yamllint** | YAML validation |
| **shellcheck** | Shell script linting |
| **ansible-lint** | Ansible validation |

### OWASP Checklist

- [x] Secret management con OpenBao
- [x] Container security scanning (Trivy)
- [x] Dependency vulnerability scanning
- [x] Infrastructure as Code validation (Checkov)
- [x] Network segmentation (3 redes)
- [x] No hardcoded credentials
- [x] GitHub Actions CI/CD con security scans

---

## 11. CI/CD - GitHub Actions

### Pipeline CI (ci.yml)

```yaml
Jobs:
  1. Linting          # Ruff, yamllint, shellcheck, ansible-lint
  2. Security Scan    # Trivy, Bandit, Hadolint
  3. Unit Tests       # pytest con coverage >85%
  4. Integration      # Tests de servicios
  5. Build Images     # Construcción de contenedores
```

### Pipeline CD (cd.yml)

```yaml
Jobs:
  1. Deploy VM        # Ansible provisioning
  2. Deploy Services # podman compose
  3. Deploy SonarQube # Análisis de código
```

---

## 12. Análisis de Código - SonarQube

### Configuración

```properties
sonar.projectKey=zabbix-testing-environment
sonar.projectName=Zabbix Testing Environment
sonar.language=py,shell,yaml,dockerfile
sonar.python.version=3.11
sonar.coverage.jacoco.xmlReportsPath=coverage.xml
```

### Servicios

| Servicio | Puerto | URL |
|----------|--------|-----|
| SonarQube | 9000 | http://localhost:9000 |
| PostgreSQL | 5432 | localhost:5432 |

---

## 13. Diagramas C4

| Nivel | Archivo | Descripción |
|-------|---------|-------------|
| **C1** | `c1-context.drawio` | Contexto del sistema |
| **C2** | `c2-container.drawio` | Contenedores y relaciones |
| **C3** | `c3-component.drawio` | Componentes internos |
| **C4** | `c4-code.drawio` | Estructura de código |

---

## 14. AI Agent Skills

### QA Skill (.github/actions/qa-skill.yml)

```yaml
Commands:
  - run-unit-tests
  - run-integration-tests
  - run-security-tests
  - run-all-tests
  - check-coverage
  - security-scan
  - lint-code
```

### Deploy Skill (.github/actions/deploy-skill.yml)

```yaml
Commands:
  - deploy-all
  - deploy-services
  - deploy-zabbix
  - deploy-sonarqube
  - start-services
  - stop-services
  - health-check
  - init-secrets
```

---

## 15. Scripts

| Script | Propósito |
|--------|-----------|
| `scripts/create-utm-vm.sh` | Crear VM en UTM |
| `scripts/cloud-init/user-data.yml` | Config cloud-init |
| `scripts/init-secrets.sh` | Poblar OpenBao |
| `scripts/health-check.sh` | Verificar servicios |

---

## 16. Flujo de Despliegue

```
1. git clone
   │
   ▼
2. tools/linters/setup-linters.sh
   │  • Ruff
   │  • yamllint
   │  • shellcheck
   ▼
3. tools/security/setup-security-tools.sh
   │  • Trivy
   │  • Bandit
   │  • Hadolint
   ▼
4. scripts/create-utm-vm.sh
   │  • Crear VM en UTM
   ▼
5. ansible-playbook prepare-vm.yml
   │  • Crear LVM (3 LV)
   │  • Instalar paquetes
   ▼
6. ansible-playbook setup-podman.yml
   │  • Instalar Podman
   ▼
7. podman compose up -d
   │  • OpenBao
   │  • PostgreSQL
   │  • Nginx
   │  • FastAPI
   │  • Zabbix 6.0, 7.0, 7.4
   ▼
8. pytest tests/ --cov-fail-under=85
   │  • Unit tests
   │  • Integration tests
   │  • Security tests
   ▼
9. trivy fs .
   │  • Vulnerability scan
   ▼
10. ./scripts/init-secrets.sh
    • Poblar OpenBao
```

---

## 17. Puertos de Acceso

| Servicio | Puerto | URL |
|----------|--------|-----|
| OpenBao | 8200 | http://localhost:8200 |
| Zabbix 6.0 | 8080 | http://localhost:8080 |
| Zabbix 7.0 | 8081 | http://localhost:8081 |
| Zabbix 7.4 | 8082 | http://localhost:8082 |
| Nginx | 80 | http://localhost:80 |
| FastAPI | 8000 | http://localhost:8000 |
| SonarQube | 9000 | http://localhost:9000 |
| PostgreSQL | 5432 | localhost:5432 |

---

## 18. Estructura de Archivos

```
.
├── README.md
├── SPEC.md
├── pyproject.toml                 # pytest + coverage
├── docker-compose.yml
├── docker-compose.sonarqube.yml
├── sonar-project.properties
│
├── scripts/
│   ├── create-utm-vm.sh
│   ├── cloud-init/
│   ├── init-secrets.sh
│   └── health-check.sh
│
├── ansible/
│   ├── prepare-vm.yml
│   ├── setup-podman.yml
│   └── roles/
│
├── configs/
│   ├── openbao/
│   ├── nginx/
│   └── fastapi/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── security/
│
├── tools/
│   ├── linters/
│   └── security/
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── cd.yml
│   └── actions/
│
└── docs/
    └── diagrams/
        ├── c1-context.drawio
        ├── c2-container.drawio
        ├── c3-component.drawio
        └── c4-code.drawio
```
