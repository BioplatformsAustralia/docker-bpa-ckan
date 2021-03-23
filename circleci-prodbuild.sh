#!/bin/bash

set -e

#
# Production (deployable) build and tests
#

if [ x"$CIRCLE_BRANCH" != x"master" -a x"$CIRCLE_BRANCH" != x"next_release" ]; then
    echo "Branch $CIRCLE_BRANCH is not deployable. Skipping prod build and tests"
    exit 0
fi

./develop.sh recurse push prod
./develop.sh recurse push prod-date
