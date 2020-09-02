#!/usr/bin/env bash
set -xeu pipefail

VERSION=${HC_VERSION}
PACKAGE_ITERATION=${HC_PACKAGE_ITERATION:-1}

# Name enterprise package consul-enterprise
PRODUCT_NAME="vault_selinux"

# Constants

# Install Vault RPM
echo "dnf installing Vault"
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf -y install vault

# Install other deps
echo "dnf installing other stuff"
sudo dnf -y install policycoreutils-devel setools-console rpm-build

OUTPUT_PATH=$(pwd)
# Create temporary workspace
echo "Creating temporary workspace"
mkdir pkg_tmp

cp ./vault.fc ./pkg_tmp/vault.fc
cp ./vault.if ./pkg_tmp/vault.if
cp ./vault.sh ./pkg_tmp/vault.sh
cp ./vault.te ./pkg_tmp/vault.te
cp ./vault_selinux.spec ./pkg_tmp/vault_selinux.spec

PACKAGE_DIR=$(cd pkg_tmp; pwd)
cd $PACKAGE_DIR

echo "Updating #VERSION# in vault.te and vault_selinux.spec"
sed -i "s^#VERSION#^${HC_VERSION}^g" vault.te
sed -i "s^#VERSION#^${HC_VERSION}^g" vault_selinux.spec

# Run the sepolicy builder
sudo sh ./vault.sh
mv *.rpm $OUTPUT_PATH
mv noarch/*.rpm $OUTPUT_PATH

# Cleanup
cd $OUTPUT_PATH
rm -rf $PACKAGE_DIR
