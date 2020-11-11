#!/bin/bash
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault

sudo yum -y install wget unzip tmux policycoreutils-devel setools-console rpm-build vim
wget https://releases.hashicorp.com/vault/1.6.0-rc/vault_1.6.0-rc_linux_amd64.zip
unzip vault_1.6.0-rc_linux_amd64.zip
sudo mv vault /usr/bin/vault
sudo cp /usr/bin/vault /usr/sbin/vault
export instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
export internal_ip="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
export external_ip="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"


sudo tee /etc/vault.d/vault.hcl > /dev/null <<EOT
ui = true

#mlock = true
#disable_mlock = true

#storage "file" {
#  path = "/opt/vault/data"
#}

storage "raft" {
  path = "/opt/vault/data"
  node_id = "$instance_id"

  retry_join {
    auto_join = "provider=aws addr_type=private_v4 tag_key=cluster_name tag_value=raft"
    auto_join_scheme = "http"
  }
}

seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_id}"
}

#storage "consul" {
#  address = "127.0.0.1:8500"
#  path    = "vault"
#}

# HTTP listener
#listener "tcp" {
#  address = "127.0.0.1:8200"
#  tls_disable = 1
#}

# HTTPS listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable = 1

#  tls_cert_file = "/opt/vault/tls/tls.crt"
#  tls_key_file  = "/opt/vault/tls/tls.key"
}
api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://$internal_ip:8201"
EOT

#
# sudo tee -a /home/centos/config.hcl > /dev/null <<EOT
# storage "raft" {
#   path = "/home/centos/data"
#   node_id = "node-1"
# }
#
# cluster_addr = "http://127.0.0.1:8201"
# api_addr = "http://0.0.0.0:8200"
#
# listener "tcp" {
#   address = "0.0.0.0:8200"
#   tls_disable = "true"
# }
# EOT
# sudo chown centos:centos /home/centos/config.hcl
#
# sudo mkdir /home/centos/data
# sudo chown centos:centos /home/centos/data
#
# sudo tee -a /home/centos/vault-bootstrap.sh > /dev/null <<EOT
# #!/bin/bash
# vault status
# vault auth enable jwt
# vault write auth/jwt/config jwks_url="https://xntrik.wtf/x5/jwk.json"
# vault write auth/jwt/role/test role_type="jwt" bound_audiences="https://vault.plugin.auth.jwt.test" user_claim="https://vault/user"
# EOT
# sudo chown centos:centos /home/centos/vault-bootstrap.sh
#
# sudo tee -a /home/centos/payload.json > /dev/null <<EOT
# {
#   "role": "test",
#   "jwt": ""
# }
# EOT
# sudo chown centos:centos /home/centos/vault-bootstrap.sh
#
# sudo useradd --system --home-dir /etc/vault.d --shell /bin/false vault
#
# sudo mkdir -p /opt/vault/data
# sudo chown vault:vault /opt/vault/data
# sudo mkdir /var/log/vault
# sudo chown vault:vault /var/log/vault
# sudo mkdir /etc/vault.d
#
# sudo tee -a /etc/vault.d/vault.hcl > /dev/null <<EOT
# storage "raft" {
#   path = "/opt/vault/data"
#   node_id = "node-1"
# }
#
# cluster_addr = "http://127.0.0.1:8201"
# api_addr = "http://0.0.0.0:8200"
#
# listener "tcp" {
#   address = "0.0.0.0:8200"
#   tls_disable = "true"
# }
# EOT
#
# sudo tee -a /etc/systemd/system/vault.service > /dev/null <<EOT
# [Unit]
# Description="HashiCorp Vault - A tool for managing secrets"
# Documentation=https://www.vaultproject.io/docs/
# Requires=network-online.target
# After=network-online.target
# ConditionFileNotEmpty=/etc/vault.d/vault.hcl
# StartLimitIntervalSec=60
# StartLimitBurst=3
#
# [Service]
# User=vault
# Group=vault
# ProtectSystem=full
# ProtectHome=read-only
# PrivateTmp=yes
# PrivateDevices=yes
# SecureBits=keep-caps
# AmbientCapabilities=CAP_IPC_LOCK
# Capabilities=CAP_IPC_LOCK+ep
# CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
# NoNewPrivileges=yes
# ExecStart=/usr/sbin/vault server -config=/etc/vault.d/vault.hcl
# ExecReload=/bin/kill --signal HUP $MAINPID
# KillMode=process
# KillSignal=SIGINT
# Restart=on-failure
# RestartSec=5
# TimeoutStopSec=30
# StartLimitInterval=60
# StartLimitIntervalSec=60
# StartLimitBurst=3
# LimitNOFILE=65536
# LimitMEMLOCK=infinity
#
# [Install]
# WantedBy=multi-user.target
# EOT
