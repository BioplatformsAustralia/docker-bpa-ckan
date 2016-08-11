#!/bin/sh
#
# Script to build images
#

: ${PROJECT_NAME:='bpa-ckan'}
. ./lib.sh

set -e

ACTION="$1"

echo ''
info "$0 $@"
docker_options
git_tag
docker_warm_cache

case $ACTION in
build)
    create_image
    ;;
publish_docker_image)
    publish_docker_image
    ;;
ci_docker_login)
    ci_docker_login
    ;;
*)
    usage
    ;;
esac
