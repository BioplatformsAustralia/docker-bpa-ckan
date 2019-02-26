#!/bin/bash

set -e

#
# Production (deployable) build and tests
#

if [ x"$BRANCH_NAME" != x"master" -a x"$BRANCH_NAME" != x"ckan-upgrade-2.8.2" ]; then
    echo "Branch $BRANCH_NAME is not deployable. Skipping prod build and tests"
    exit 0
fi

./develop.sh recurse push prod
./develop.sh recurse push prod-date
