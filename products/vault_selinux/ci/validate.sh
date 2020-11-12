#!/usr/bin/env bash
set -eux

# This script is executed from a circleci machine executor to
# validate the Linux rpm packages for vault_selinux

WORKDIR=$(pwd)

# Let our docker containers write to mounted volumes
if ! [ -z "${CI:-""}" ]; then
  chmod a+rwx -R ./
fi

# Run CentOS rpm validation
CENTOS_ID=$(docker run -d -v $WORKDIR:/app -e HC_PRODUCT=$HC_PRODUCT -e HC_VERSION=$HC_VERSION \
  --entrypoint="" -w="/app" --privileged $IMAGE_CENTOS_SYSTEM /usr/sbin/init)
# Wait for CentOS to spin up
sleep 1
docker exec $CENTOS_ID yum install -y libselinux-utils policycoreutils policycoreutils-python-utils selinux-policy-targeted
docker exec $CENTOS_ID yum install -y /app/$(ls products/*/*el8.noarch.rpm)

docker exec $CENTOS_ID bash -c 'semanage module -l | grep vault'
docker exec $CENTOS_ID bash -c 'semanage port -l | grep vault_cluster_port_t'
docker exec $CENTOS_ID bash -c 'semanage boolean -l | grep vault_outbound'
docker exec $CENTOS_ID yum remove -y vault_selinux

docker stop $CENTOS_ID

# Run Fedora rpm validation
FEDORA_ID=$(docker run -d -v $WORKDIR:/app -e HC_PRODUCT=$HC_PRODUCT -e HC_VERSION=$HC_VERSION \
  --entrypoint="" -w="/app" --privileged $IMAGE_RPM_SYSTEM /usr/sbin/init)
# Wait for Fedora to spin up
sleep 1
docker exec $FEDORA_ID dnf install -y libselinux-utils policycoreutils policycoreutils-python-utils selinux-policy-targeted
docker exec $FEDORA_ID dnf install -y /app/$(ls products/*/*fc31.noarch.rpm)

docker exec $FEDORA_ID bash -c 'semanage module -l | grep vault'
docker exec $FEDORA_ID bash -c 'semanage port -l | grep vault_cluster_port_t'
docker exec $FEDORA_ID bash -c 'semanage boolean -l | grep vault_outbound'
docker exec $FEDORA_ID dnf remove -y vault_selinux

docker stop $FEDORA_ID

echo "Validation tests complete."
