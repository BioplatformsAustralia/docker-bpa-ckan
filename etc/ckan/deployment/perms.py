#!/usr/bin/env python

import os
import sqlalchemy


def setup_readonly():
    engine = sqlalchemy.create_engine(os.environ['CKAN_DATASTORE_WRITE_URL'])
    connection = engine.connect()
    connection.execute("CREATE USER readonly WITH PASSWORD 'readonly';")
    connection.close()


def setup_gis_perms():
    engine = sqlalchemy.create_engine(os.environ['CKAN_SQLALCHEMY_URL'])
    connection = engine.connect()
    connection.execute("ALTER VIEW geometry_columns OWNER TO ckan;")
    connection.execute("ALTER TABLE spatial_ref_sys OWNER TO ckan;")
    connection.close()

if __name__ == '__main__':
    setup_readonly()
    setup_gis_perms()
