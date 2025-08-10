storage "postgresql" {
  connection_url = "postgresql://postgres:[password]@localhost:5432/postgres"
}

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_disable        = 1
}

cluster_addr  = "http://127.0.0.1:8201"
api_addr      = "http://127.0.0.1:8200"
ui = true
log_level = "INFO"
disable_mlock = true