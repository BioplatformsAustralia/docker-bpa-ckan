#!/bin/bash

. /docker-entrypoint.sh
set +e
. /env/bin/activate
cd /etc/ckan/deployment/ || exit 1
echo "** fixing up database permissions **"
python /etc/ckan/deployment/perms.py
echo "** db init"
# paster --plugin=ckan db init
ckan -c /etc/ckan/default/ckan.ini db init
echo "** datastore permissions"
ckan -c /etc/ckan/default/ckan.ini datastore set-permissions
echo "** create sysadmin"
ckan -c /etc/ckan/default/ckan.ini sysadmin add admin
