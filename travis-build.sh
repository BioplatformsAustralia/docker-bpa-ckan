#!/bin/bash

set -e 

#
# Development build and tests
#

# bioplatforms-composer runs as this UID, and needs to be able to
# create output directories within it
mkdir -p data/
sudo chown 1000:1000 data/

./develop.sh sanity
./develop.sh recurse build prod
./develop.sh recurse build prod-date
