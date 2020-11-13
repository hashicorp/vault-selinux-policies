#!/bin/bash
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault-1.6.0-1

sudo yum -y install wget unzip tmux policycoreutils-devel setools-console rpm-build vim
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

