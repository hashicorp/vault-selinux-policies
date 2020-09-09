#!/usr/bin/env bash
set -eux

# This script is executed from a circleci machine executor to
# validate the Linux rpm packages for vault_selinux

WORKDIR=$(pwd)

# Let our docker containers write to mounted volumes
if ! [ -z "${CI:-""}" ]; then
  chmod a+rwx -R ./
fi

# Run rpm validation
CENTOS_ID=$(docker run -d -v $WORKDIR:/app -e HC_PRODUCT=$HC_PRODUCT -e HC_VERSION=$HC_VERSION \
  --entrypoint="" -w="/app" --privileged $IMAGE_CENTOS_SYSTEM /usr/sbin/init)
# Wait for CentOS to spin up
sleep 1
docker exec $CENTOS_ID yum install -y libselinux-utils policycoreutils policycoreutils-python-utils selinux-policy-targeted
#docker exec $CENTOS_ID yum install -y /app/$(ls products/*/*el*.noarch.rpm)

docker exec $CENTOS_ID bash -c 'semanage module -l | grep vault'

docker stop $CENTOS_ID

echo "Validation tests complete."
