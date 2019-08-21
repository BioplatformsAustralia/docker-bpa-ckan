FROM python:2.7-slim
LABEL maintainer "https://github.com/BioplatformsAustralia"

ENV VIRTUAL_ENV /env
ENV PYTHON_PIP_VERSION 9.0.1
ENV PIP_NO_CACHE_DIR="off"

# create a virtual env in $VIRTUAL_ENV and ensure it respects pip version
RUN pip install --upgrade virtualenv \
    && virtualenv $VIRTUAL_ENV \
    && $VIRTUAL_ENV/bin/pip install --upgrade pip==$PYTHON_PIP_VERSION
ENV PATH $VIRTUAL_ENV/bin:$PATH
ENV PROJECT_NAME ckan
ENV CKAN_HOME $VIRTUAL_ENV
ENV PIP_NO_CACHE_DIR "off"

RUN mkdir /app

RUN addgroup --gid 1000 bioplatforms \
  && adduser --disabled-password --home /data --no-create-home --system -q --uid 1000 --ingroup bioplatforms bioplatforms \
  && mkdir /data \
  && chown bioplatforms:bioplatforms /data

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
  python-pil \
  zlib1g-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /etc/ckan /var/www/storage && \
    chown -R bioplatforms /var/www

COPY etc/ckan /etc/ckan/
COPY etc/uwsgi /etc/uwsgi/

# http://docs.ckan.org/en/latest/maintaining/installing/install-from-source.html
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/requirements.txt

RUN curl -o /etc/ckan/ckanext-spatial-requirements.txt https://raw.githubusercontent.com/BioplatformsAustralia/ckanext-spatial/0.2.1/pip-requirements.txt \
  && NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/ckanext-spatial-requirements.txt

RUN curl -o /etc/ckan/ckan-requirements.txt https://raw.githubusercontent.com/ckan/ckan/ckan-2.6.1/requirements.txt \
  && NO_PROXY=${PIP_TRUSTED_HOST} pip install --upgrade -r /etc/ckan/ckan-requirements.txt

# this is a hack: html5lib made a breaking change, and it's broken the whole
# ckan universe. rather than forking everything, hard wire the fix here for now.
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install html5lib==0.999
# same for celery
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install celery==3.1.25
# https://github.com/geoalchemy/geoalchemy2/issues/213
RUN NO_PROXY=${PIP_TRUSTED_HOST} pip install GeoAlchemy2==0.5.0


COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN curl -o /etc/ckan/default/who.ini https://raw.githubusercontent.com/ckan/ckan/ckan-2.5.2/ckan/config/who.ini

EXPOSE 9100 9101
VOLUME ["/data", "/var/www/storage"]

RUN chown -R bioplatforms /etc/ckan/default/

# Drop privileges, set home for bioplatforms
USER bioplatforms
ENV HOME /data
WORKDIR /data

# entrypoint shell script that by default starts uwsgi
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uwsgi"]
