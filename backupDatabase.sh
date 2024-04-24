#!/bin/bash

# A script to take a database backup from a running database container

# Example usage, expected within deploy user crontab:
# 0 18 * * SUN /home/deploy/backupDatabase.sh

# Requirements:
# A running bitnami postgres container `deploy_database_1` or `deploy-database-1`
# Ability to run `docker exec` on the above container.
# Assumes paths and environment variables based on bitnami postgres container.

set -e

container=$(docker ps --filter='name=deploy[_-]database[_-]1' -q)
docker exec "${container}" /bin/bash -c 'backupfile=/bitnami/postgresql/pdc_$(date --utc +'%Y%m%dT%H%MZ').pgdump \
  && touch ${backupfile} \
  && chmod 600 ${backupfile} \
  && PGPASSWORD=${POSTGRESQL_PASSWORD} /opt/bitnami/postgresql/bin/pg_dump \
    -p ${POSTGRESQL_PORT_NUMBER} \
    -U ${POSTGRESQL_USERNAME} \
    -d ${POSTGRESQL_DATABASE} \
    -Fc -f ${backupfile}'
