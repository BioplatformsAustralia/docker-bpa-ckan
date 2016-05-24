#!/bin/sh
#
# Script to build images
#

# break on error
set -e

REPO="muccg"
DATE=`date +%Y.%m.%d`

VERSION="0.0.1"

if [ x"$1" = xproxy ]; then
    echo "using proxy"
    DOCKER_HOST=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
    HTTP_PROXY="http://${DOCKER_HOST}:3128"
    PIP_INDEX_URL="http://${DOCKER_HOST}:3141/root/pypi/+simple/"
    PIP_TRUSTED_HOST=${DOCKER_HOST}
    : ${DOCKER_BUILD_OPTIONS:="--no-cache --pull=true --build-arg ARG_PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST} --build-arg ARG_PIP_INDEX_URL=${PIP_INDEX_URL}"}
else
    echo "not using proxy"
    : ${DOCKER_BUILD_OPTIONS:="--pull=true"}
fi

echo $DOCKER_BUILD_OPTIONS

image="${REPO}/bpa-ckan"
echo "################################################################### ${image}"
## warm up cache for CI
docker pull ${image} || true

for tag in "${image}:latest" "${image}:latest-${DATE}" "${image}:${VERSION}"; do
    echo "############################################################# ${tag}"
    set -x
    docker build ${DOCKER_BUILD_OPTIONS} -t ${tag} .
    docker inspect ${tag}
    docker push ${tag}
    set +x
done
