#!/usr/bin/env bash
set -xeu pipefail

VERSION=${HC_VERSION}
PACKAGE_ITERATION=${HC_PACKAGE_ITERATION:-1}

# Name enterprise package consul-enterprise
PRODUCT_NAME="vault_selinux"

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

# Check for CentOS or Fedora

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$NAME
fi

if [[ $OS == *"CentOS"* ]]; then
  echo "Detected CentOS"

  # Install Vault RPM
  echo "yum installing Vault"
  yum install -y yum-utils
  yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  yum -y install vault

  # Install other deps
  echo "yum installing other stuff"
  yum -y install policycoreutils-devel setools-console rpm-build selinux-policy-devel selinux-policy-targeted

  # echo "Updating vault_selinux.spec for CentOS"
  # sed -i "s^#SEMANAGE#^^g" vault_selinux.spec

# @TODO - eventually remove this OS check and logic
# We probably never hit this anymore since this will be built on the ESPD team's container ?
elif [[ $OS == *"Fedora"* ]]; then
  echo "Detected Fedora"

  # Install Vault RPM
  echo "dnf installing Vault"
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  dnf -y install vault

  # Install other deps
  echo "dnf installing other stuff"
  dnf -y install policycoreutils-devel setools-console rpm-build

  # echo "Updating vault_selinux.spec for Fedora"
  # sed -i "s^#SEMANAGE#^, policycoreutils-python-utils^g" vault_selinux.spec

fi

echo "Updating #VERSION# in vault.te and vault_selinux.spec"
sed -i "s^#VERSION#^${HC_VERSION}^g" vault.te
sed -i "s^#VERSION#^${HC_VERSION}^g" vault_selinux.spec

# Run the sepolicy builder
sh ./vault.sh
cp *.rpm $OUTPUT_PATH
cp noarch/*.rpm $OUTPUT_PATH

# Cleanup
cd $OUTPUT_PATH
rm -rf $PACKAGE_DIR

# # Now we do everything again for the Fedora package, which has a slightly different
# # spec file
# # Create temporary workspace
# echo "Creating temporary workspace"
# mkdir pkg_tmp
#
# cp ./vault.fc ./pkg_tmp/vault.fc
# cp ./vault.if ./pkg_tmp/vault.if
# cp ./vault.sh ./pkg_tmp/vault.sh
# cp ./vault.te ./pkg_tmp/vault.te
# cp ./vault_selinux.spec ./pkg_tmp/vault_selinux.spec
#
# PACKAGE_DIR=$(cd pkg_tmp; pwd)
# cd $PACKAGE_DIR
#
# # Check for CentOS or Fedora
#
# if [ -f /etc/os-release ]; then
#   . /etc/os-release
#   OS=$NAME
# fi
#
# if [[ $OS == *"CentOS"* ]]; then
#   echo "Detected CentOS"
#
#   # Install Vault RPM
#   echo "yum installing Vault"
#   yum install -y yum-utils
#   yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#   yum -y install vault
#
#   # Install other deps
#   echo "yum installing other stuff"
#   yum -y install policycoreutils-devel setools-console rpm-build selinux-policy-devel selinux-policy-targeted
#
#   # echo "Updating vault_selinux.spec for Fedora"
#   # sed -i "s^#SEMANAGE#^, policycoreutils-python-utils^g" vault_selinux.spec
#
# # @TODO - eventually remove this OS check and logic
# # We probably never hit this anymore since this will be built on the ESPD team's container ?
# elif [[ $OS == *"Fedora"* ]]; then
#   echo "Detected Fedora"
#
#   # Install Vault RPM
#   echo "dnf installing Vault"
#   dnf install -y dnf-plugins-core
#   dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
#   dnf -y install vault
#
#   # Install other deps
#   echo "dnf installing other stuff"
#   dnf -y install policycoreutils-devel setools-console rpm-build
#
#   # echo "Updating vault_selinux.spec for Fedora"
#   # sed -i "s^#SEMANAGE#^, policycoreutils-python-utils^g" vault_selinux.spec
#
# fi
#
# echo "Updating #VERSION# in vault.te and vault_selinux.spec"
# sed -i "s^#VERSION#^${HC_VERSION}^g" vault.te
# sed -i "s^#VERSION#^${HC_VERSION}^g" vault_selinux.spec
#
# # Run the sepolicy builder
# sh ./vault.sh
# rename el8 fc32 *.rpm
# cp *.rpm $OUTPUT_PATH
# rename el8 fc32 noarch/*.rpm
# cp noarch/*.rpm $OUTPUT_PATH
#
# # Cleanup
# cd $OUTPUT_PATH
# rm -rf $PACKAGE_DIR
