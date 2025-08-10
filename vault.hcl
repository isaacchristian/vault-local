storage "postgresql" {
  connection_url = "postgresql://postgres:[password]@localhost:5432/postgres"
}

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_disable        = 1
# tls_cert_file      = "/opt/vault/tls/int/vault.crt"
# tls_key_file       = "/opt/vault/tls/int/vault.key"
# tls_client_ca_file = "/opt/vault/tls/int/rootvaultCA.crt"
}

cluster_addr  = "http://127.0.0.1:8201"
api_addr      = "http://127.0.0.1:8200"
ui = true
log_level = "INFO"
disable_mlock = true