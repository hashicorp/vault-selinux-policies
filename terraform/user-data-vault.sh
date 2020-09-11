#!/bin/bash
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo yum -y install wget unzip tmux policycoreutils-devel setools-console rpm-build vim
wget https://releases.hashicorp.com/vault/1.5.0/vault_1.5.0_linux_amd64.zip
unzip vault_1.5.0_linux_amd64.zip
sudo mv vault /usr/bin/vault
sudo cp /usr/bin/vault /usr/sbin/vault

sudo useradd --system --home-dir /etc/vault.d --shell /bin/false vault

sudo mkdir -p /opt/vault/data
sudo chown vault:vault /opt/vault/data
sudo mkdir /var/log/vault
sudo chown vault:vault /var/log/vault
sudo mkdir /etc/vault.d

sudo tee -a /etc/vault.d/vault.hcl > /dev/null <<EOT
storage "raft" {
  path = "/opt/vault/data"
  node_id = "node-1"
}

cluster_addr = "http://127.0.0.1:8201"
api_addr = "http://0.0.0.0:8200"

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}
EOT

sudo tee -a /etc/systemd/system/vault.service > /dev/null <<EOT
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/sbin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl enable vault.service
