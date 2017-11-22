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

    : ${CKAN_INI="/etc/ckan/default/ckan.ini"}
    : ${CKAN_SQLALCHEMY_URL="postgres://${DBUSER}:${DBPASS}@${DBSERVER}/${DBNAME}"}
    : ${CKAN_DATASTORE_WRITE_URL="postgres://${DATASTORE_DBUSER}:${DATASTORE_DBPASS}@${DATASTORE_DBSERVER}/${DATASTORE_DBNAME}"}
    : ${CKAN_DATASTORE_READ_URL="postgres://${DATASTORE_DB_READONLY_USER}:${DATASTORE_DB_READONLY_PASS}@${DATASTORE_DBSERVER}/${DATASTORE_DBNAME}"}
    : ${CKAN_SOLR_URL="http://solr:8983/solr/ckan"}
    : ${CKAN_SITE_URL:="https://localhost:8443/app/"}
    : ${GOOGLE_UA:="UA-UNSET"}
    : ${CKAN_STORAGE_PATH:='/var/www/storage/'}
    : ${CKAN_PREFIX:='/app'}

    : ${MAILGUN_API_KEY:="${MAILGUN_API_KEY}"}

    export DBSERVER DBPORT DBUSER DBNAME DBPASS MEMCACHE DOCKER_ROUTE
    export DATASTORE_DBSERVER DATASTORE_DBPORT DATASTORE_DBUSER DATASTORE_DBNAME DATASTORE_DBPASS
    export CKAN_INI CKAN_SITE_URL CKAN_SQLALCHEMY_URL CKAN_DATASTORE_WRITE_URL CKAN_DATASTORE_READ_URL GOOGLE_UA CKAN_SOLR_URL CKAN_STORAGE_PATH
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET_NAME AWS_STORAGE_PATH SESSION_SECRET
    export EMAIL_TO EMAIL_FROM SMTP_SERVER SMTP_USER SMTP_PASSWORD SMTP_MAIL_FROM CKAN_PREFIX

    export MAILGUN_API_KEY
    export MAILGUN_API_DOMAIN
    export MAILGUN_SENDER_EMAIL
    export MAILGUN_RECEIVER_EMAIL

    export REGISTRATION_ERROR_LOG_FILE_PATH
    export REGISTRATION_ERROR_LOG_FILE_NAME

    export CAPTCHA_PUBLIC_KEY
    export CAPTCHA_PRIVATE_KEY

}

function make_config {
    cat /etc/ckan/default/ckan.ini.in | \
        sed -e "s#@AWS_ACCESS_KEY_ID@#$AWS_ACCESS_KEY_ID#" \
            -e "s#@AWS_SECRET_ACCESS_KEY@#$AWS_SECRET_ACCESS_KEY#" \
            -e "s#@AWS_BUCKET_NAME@#$AWS_BUCKET_NAME#" \
            -e "s#@AWS_STORAGE_PATH@#$AWS_STORAGE_PATH#" \
            -e "s#@EMAIL_TO@#$EMAIL_TO#" \
            -e "s#@EMAIL_FROM@#$EMAIL_FROM#" \
            -e "s#@PREFIX@#$CKAN_PREFIX#" \
            -e "s#@SMTP_SERVER@#$SMTP_SERVER#" \
            -e "s#@SMTP_USER@#$SMTP_USER#" \
            -e "s#@SMTP_PASSWORD@#$SMTP_PASSWORD#" \
            -e "s#@SMTP_MAIL_FROM@#$SMTP_MAIL_FROM#" \
            -e "s#@CKAN_SITE_URL@#$CKAN_SITE_URL#" \
            -e "s#@GOOGLE_UA@#$GOOGLE_UA#" \
            -e "s#@CAPTCHA_PUBLIC_KEY@#$CAPTCHA_PUBLIC_KEY#" \
            -e "s#@CAPTCHA_PRIVATE_KEY@#$CAPTCHA_PRIVATE_KEY#" \
            -e "s#@SESSION_SECRET@#$SESSION_SECRET#" > /etc/ckan/default/ckan.ini
}


trap exit SIGHUP SIGINT SIGTERM
defaults
make_config
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

    # due to the huge number of packages, this is too slow to run every startup
    #
    # # sync up with the SOLR server after container restart
    # echo "** rebuilding Solr index"
    # paster --plugin=ckan search-index rebuild -c /etc/ckan/default/ckan.ini

    exec uwsgi --die-on-term --ini ${UWSGI_OPTS}
fi

echo "[RUN]: Builtin command not provided [uwsgi]"
echo "[RUN]: $@"

exec "$@"
