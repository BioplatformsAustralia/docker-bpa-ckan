FROM python:3.9-slim
LABEL maintainer "https://github.com/BioplatformsAustralia"

RUN addgroup --gid 1000 bioplatforms \
  && adduser --disabled-password --home /data --no-create-home --system -q --uid 1000 --ingroup bioplatforms bioplatforms \
  && mkdir /data \
  && chown bioplatforms:bioplatforms /data

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libmagic1 \
  libgeos-3.9.0 \
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
  python3-pil \
  zlib1g-dev \
  proj-bin \
  libproj-dev \
  xmlsec1 \
  rustc \
  cargo \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /etc/ckan /var/www/storage && \
    chown -R bioplatforms /var/www

RUN mkdir /etc/saml2auth/

COPY etc/ckan /etc/ckan/
COPY etc/uwsgi /etc/uwsgi/
COPY etc/saml2auth /etc/saml2auth/

RUN mkdir /app /env
RUN chown bioplatforms /app /env
RUN chown -R bioplatforms /etc/ckan/default/ /etc/ckan/requirements/ /etc/uwsgi/ /etc/saml2auth/

RUN pip install --upgrade virtualenv pip

# Drop privileges, set home for bioplatforms
USER bioplatforms
ENV HOME /data
WORKDIR /data

ENV VIRTUAL_ENV /env
ENV PYTHON_PIP_VERSION 22.1.2
ENV PIP_NO_CACHE_DIR="off"

# create a virtual env in $VIRTUAL_ENV and ensure it respects pip version
RUN virtualenv $VIRTUAL_ENV && $VIRTUAL_ENV/bin/pip install --upgrade pip==$PYTHON_PIP_VERSION
ENV PATH $VIRTUAL_ENV/bin:$PATH
ENV PROJECT_NAME ckan
ENV CKAN_HOME $VIRTUAL_ENV
ENV PIP_NO_CACHE_DIR "off"
ENV PYTHONUNBUFFERED 1

# http://docs.ckan.org/en/latest/maintaining/installing/install-from-source.html
RUN cat /etc/ckan/requirements/bioplatforms-requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/bioplatforms-requirements.txt

RUN curl -o /etc/ckan/requirements/ckanext-spatial-requirements.txt https://raw.githubusercontent.com/BioplatformsAustralia/ckanext-spatial/v1.0.0bioplatforms1/requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/ckanext-spatial-requirements.txt

RUN curl -o /etc/ckan/requirements/ckanext-harvest-requirements.txt https://raw.githubusercontent.com/ckan/ckanext-harvest/v1.4.0/pip-requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/ckanext-harvest-requirements.txt

RUN curl -o /etc/ckan/requirements/ckanext-googleanalytics-requirements.txt https://raw.githubusercontent.com/BioplatformsAustralia/ckanext-googleanalytics/v2.0.7bioplatforms1/requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/ckanext-googleanalytics-requirements.txt

RUN curl -o /etc/ckan/requirements/ckan-requirements.txt https://raw.githubusercontent.com/BioplatformsAustralia/ckan/bioplatforms-2.9/requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/ckan-requirements.txt

RUN curl -o /etc/ckan/requirements/ckan-requirements.txt https://raw.githubusercontent.com/tino097/ckanext-saml2auth/main/dev-requirements.txt \
  && pip install --upgrade -r /etc/ckan/requirements/ckan-requirements.txt

RUN cat /etc/ckan/requirements/bioplatforms-post-ckan-requirements.txt
RUN pip install --upgrade -r /etc/ckan/requirements/bioplatforms-post-ckan-requirements.txt

# pin celery version
RUN pip install celery==5.2.7
RUN pip install GeoAlchemy2==0.11.1

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN curl -o /etc/ckan/default/who.ini https://raw.githubusercontent.com/ckan/ckan/ckan-2.9.5/ckan/config/who.ini
RUN curl -o /etc/ckan/default/wsgi.py https://raw.githubusercontent.com/ckan/ckan/ckan-2.9.5/wsgi.py
RUN pip install -U --no-binary :all: psycopg2

EXPOSE 9100 9101
VOLUME ["/data", "/var/www/storage"]

# entrypoint shell script that by default starts uwsgi
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uwsgi"]
