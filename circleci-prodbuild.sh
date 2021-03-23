#!/bin/bash

set -e

#
# Production (deployable) build and tests
#

docker build -t bioplatformsaustralia/${GIT_REPO_NAME}:latest .
docker push bioplatformsaustralia/${GIT_REPO_NAME}
if [ x"$GIT_TAG" != x"" ]; then
  docker tag bioplatformsaustralia/${GIT_REPO_NAME}:latest bioplatformsaustralia/${GIT_REPO_NAME}:${GIT_TAG}
  docker push bioplatformsaustralia/${GIT_REPO_NAME}:${GIT_TAG}
fi
