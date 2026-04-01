# =============================================================================
# OpenBao Configuration for POD1 - CI/CD DevSecOps
# =============================================================================
# Author: Andrés M. Correa
# Description: HashiCorp Vault-compatible secrets management
# =============================================================================

listener "tcp" {
  address = "[::]:8200"
  cluster_address = "[::]:8201"
  tls_disable = "true"
}

storage "file" {
  path = "/openbao/data"
}

ui = true

service_registration "kubernetes" {}

# Disable telemetry for local dev
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Dev mode settings
disable_mlock = true