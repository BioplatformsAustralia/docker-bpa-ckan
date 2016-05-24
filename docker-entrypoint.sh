#!/bin/bash


# wait for a given host:port to become available
#
# $1 host
# $2 port
function dockerwait {
    while ! exec 6<>/dev/tcp/$1/$2; do
        echo "$(date) - waiting to connect $1 $2"
        sleep 5
    done
    echo "$(date) - connected to $1 $2"

    exec 6>&-
    exec 6<&-
}


# wait for services to become available
# this prevents race conditions using fig
function wait_for_services {
    if [[ "$WAIT_FOR_DB" ]] ; then
        dockerwait $DBSERVER $DBPORT
    fi
    if [[ "$WAIT_FOR_DATASTORE" ]] ; then
        dockerwait $DATASTORE_DBSERVER $DATASTORE_DBPORT
    fi
    if [[ "$WAIT_FOR_CACHE" ]] ; then
        dockerwait $CACHESERVER $CACHEPORT
    fi
    if [[ "$WAIT_FOR_SOLR" ]] ; then
        dockerwait $SOLRSERVER $SOLRPORT
    fi
    if [[ "$WAIT_FOR_HOST_PORT" ]]; then
        dockerwait $DOCKER_ROUTE $WAIT_FOR_HOST_PORT
    fi
}


function defaults {
    : ${DBSERVER:="db"}
    : ${DBPORT:="5432"}
    : ${DBUSER:="webapp"}
    : ${DBNAME:="${DBUSER}"}
    : ${DBPASS:="${DBUSER}"}

    : ${DATASTORE_DBSERVER:="datastore"}
    : ${DATASTORE_DBPORT:="5432"}
    : ${DATASTORE_DBUSER:="datastore"}
    : ${DATASTORE_DBNAME:="${DATASTORE_DBUSER}"}
    : ${DATASTORE_DBPASS:="${DATASTORE_DBUSER}"}
    : ${DATASTORE_DB_READONLY_USER:="readonly"}
    : ${DATASTORE_DB_READONLY_PASS:="${DATASTORE_DB_READONLY_USER}"}

    : ${DOCKER_ROUTE:=$(/sbin/ip route|awk '/default/ { print $3 }')}

    : ${CACHESERVER:="cache"}
    : ${CACHEPORT:="11211"}
    : ${MEMCACHE:="${CACHESERVER}:${CACHEPORT}"}

    : ${SOLRSERVER:="solr"}
    : ${SOLRPORT:="8983"}

    # currently supported environment variables
    # while these are useful, annoyingly they aren't respect when using paster
    : ${CKAN_INI="/etc/ckan/default/ckan.ini"}
    #'sqlalchemy.url': 'CKAN_SQLALCHEMY_URL',
    : ${CKAN_SQLALCHEMY_URL="postgres://${DBUSER}:${DBPASS}@${DBSERVER}/${DBNAME}"}
    #'ckan.datastore.write_url': 'CKAN_DATASTORE_WRITE_URL',
    #'ckan.datastore.read_url': 'CKAN_DATASTORE_READ_URL',
    : ${CKAN_DATASTORE_WRITE_URL="postgres://${DATASTORE_DBUSER}:${DATASTORE_DBPASS}@${DATASTORE_DBSERVER}/${DATASTORE_DBNAME}"}
    : ${CKAN_DATASTORE_READ_URL="postgres://${DATASTORE_DB_READONLY_USER}:${DATASTORE_DB_READONLY_PASS}@${DATASTORE_DBSERVER}/${DATASTORE_DBNAME}"}
    #'solr_url': 'CKAN_SOLR_URL',
    : ${CKAN_SOLR_URL="http://solr:8983/solr/ckan"}
    #'ckan.site_id': 'CKAN_SITE_ID',
    #'ckan.site_url': 'CKAN_SITE_URL',
    : ${CKAN_SITE_URL:="https://localhost:8443/app/"}
    : ${CKAN_STORAGE_PATH:='/var/www/storage/'}
    #'ckan.datapusher.url': 'CKAN_DATAPUSHER_URL',
    #'smtp.server': 'CKAN_SMTP_SERVER',
    #'smtp.starttls': 'CKAN_SMTP_STARTTLS',
    #'smtp.user': 'CKAN_SMTP_USER',
    #'smtp.password': 'CKAN_SMTP_PASSWORD',
    #'smtp.mail_from': 'CKAN_SMTP_MAIL_FROM'

    export DBSERVER DBPORT DBUSER DBNAME DBPASS MEMCACHE DOCKER_ROUTE
    export DATASTORE_DBSERVER DATASTORE_DBPORT DATASTORE_DBUSER DATASTORE_DBNAME DATASTORE_DBPASS
    export CKAN_INI CKAN_SITE_URL CKAN_SQLALCHEMY_URL CKAN_DATASTORE_WRITE_URL CKAN_DATASTORE_READ_URL CKAN_SOLR_URL CKAN_STORAGE_PATH
}


trap exit SIGHUP SIGINT SIGTERM
defaults
env | grep -iv PASS | sort
wait_for_services

# Some test code to dump out how ckan talks to solr
#(tcpdump -n -i eth0 port 8983 -t -A 2>&1 &)

# POST /solr/ckan/select HTTP/1.1
# Host: solr:8983
# Accept-Encoding: identity
# Content-Length: 57
# Content-Type: application/x-www-form-urlencoded; charset=utf-8
# 
# q=%2A%3A%2A&rows=1&fl=%2A%2Cscore&version=2.2&wt=standard

# GET /solr/ckan/admin/file/?file=schema.xml HTTP/1.1
# Accept-Encoding: identity
# Host: solr:8983
# Connection: close
# User-Agent: Python-urllib/2.7

# uwsgi entrypoint
if [ "$1" = 'uwsgi' ]; then
    echo "[Run] Starting uwsgi"

    : ${UWSGI_OPTS="/etc/uwsgi/uwsgi.ini"}
    echo "UWSGI_OPTS is ${UWSGI_OPTS}"

    exec uwsgi --die-on-term --ini ${UWSGI_OPTS}
fi

echo "[RUN]: Builtin command not provided [uwsgi]"
echo "[RUN]: $@"

exec "$@"
