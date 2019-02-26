FROM muccg/python-base:2.7-debian-8
MAINTAINER https://github.com/muccg/bpa-ckan-docker

# At build time change these args to use a local devpi mirror
# Unchanged, these defaults allow pip to behave as normal
ARG ARG_PIP_INDEX_URL="https://pypi.python.org/simple"
ARG ARG_PIP_TRUSTED_HOST="127.0.0.1"

ENV PROJECT_NAME ckan
ENV CKAN_HOME $VIRTUAL_ENV
ENV PIP_INDEX_URL $ARG_PIP_INDEX_URL
ENV PIP_TRUSTED_HOST $ARG_PIP_TRUSTED_HOST
ENV PIP_NO_CACHE_DIR "off"

RUN env | sort

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libgeos-3.5.1 \
  libjpeg-dev \
  libpcre3 \
  libpcre3-dev \
  libpng-dev \
  libpq5 \
  libpq-dev \
  libssl-dev \
  libyaml-dev \
  libxml2 \
  libxml2-dev \
  libxslt1-dev \
  libmagic1 \
  python-pil \
  zlib1g-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /etc/ckan /var/www/storage && \
  chown -R ccg-user /var/www

COPY etc/ckan /etc/ckan/
COPY etc/uwsgi /etc/uwsgi/

# http://docs.ckan.org/en/latest/maintaining/installing/install-from-source.html
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/requirements.txt

RUN curl -o /etc/ckan/ckanext-spatial-requirements.txt https://raw.githubusercontent.com/muccg/ckanext-spatial/0.2.1/pip-requirements.txt \
  && NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/ckanext-spatial-requirements.txt

#RUN curl -o /etc/ckan/ckan-requirements.txt https://raw.githubusercontent.com/ckan/ckan/ckan-2.6.1/requirements.txt \
RUN curl -o /etc/ckan/ckan-requirements.txt https://raw.githubusercontent.com/ckan/ckan/ckan-2.8.2/requirements.txt \
  && NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/ckan-requirements.txt

# this is a hack: html5lib made a breaking change, and it's broken the whole
# ckan universe. rather than forking everything, hard wire the fix here for now.
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install html5lib==1.0.1

# same for celery
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install celery==3.1.25

COPY docker-entrypoint.sh /docker-entrypoint.sh
#RUN curl -o /etc/ckan/default/who.ini https://raw.githubusercontent.com/ckan/ckan/ckan-2.5.2/ckan/config/who.ini
RUN curl -o /etc/ckan/default/who.ini https://raw.githubusercontent.com/ckan/ckan/ckan-2.8.2/ckan/config/who.ini

EXPOSE 9100 9101
VOLUME ["/data", "/var/www/storage"]

# CKAN needs to be able to write translations in here
RUN chown -R ccg-user /env/lib/python2.7/site-packages/ckan/public/base/i18n/
RUN chown -R ccg-user /etc/ckan/default/

# Drop privileges, set home for ccg-user
USER ccg-user
ENV HOME /data
WORKDIR /data

# entrypoint shell script that by default starts uwsgi
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uwsgi"]
