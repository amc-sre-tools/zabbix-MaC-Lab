cluster_name = "zabbix-testing-cluster"

storage "raft" {
  path = "/openbao/data"
  node_id = "openbao-node-1"
  retry_join {
    leader_api_addr = "http://openbao:8200"
  }
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

disable_printable_check = true

service_registration "kubernetes" {
  enabled = false
}
