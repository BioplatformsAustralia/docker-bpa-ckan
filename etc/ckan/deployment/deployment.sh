#!/bin/bash

. /docker-entrypoint.sh
set +e
. /env/bin/activate
cd /etc/ckan/deployment/ || exit 1
echo "** fixing up database permissions **"
python /etc/ckan/deployment/perms.py
echo "** db init"
ckan db init
echo "** datastore permissions"
ckan datastore set-permissions | psql "$CKAN_DATASTORE_WRITE_URL"
echo "** create sysadmin"
ckan sysadmin add admin
echo "** setup ytp-request"
ckan opendata-request init-db
