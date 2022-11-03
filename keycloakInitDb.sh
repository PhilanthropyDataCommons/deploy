#!/bin/bash

# Adds a 'keycloak' role and 'keycloak' database to a postgres instance.
# The 'keycloak' database will be owned by the 'keycloak' role.
# KEYCLOAK_PG_PASSWORD has the desired passphrase for the role.
# POSTGRESQL_POSTGRES_PASSWORD has the passphrase for the postgres user.
# POSTGRESQL_PORT_NUMBER has the pg server port, optional.

set -eo pipefail

if [[ "${KEYCLOAK_PG_PASSWORD}" == "" ]]
then
    echo "KEYCLOAK_PG_PASSWORD empty or not found!"
    exit 1
fi

if [[ "${POSTGRESQL_POSTGRES_PASSWORD}" == "" ]]
then
    echo "POSTGRESQL_POSTGRES_PASSWORD empty or not found!"
    exit 2
fi

PGPASSWORD="${POSTGRESQL_POSTGRES_PASSWORD}" psql -d postgres -U postgres -c "create role keycloak with nosuperuser nocreatedb nocreaterole login password '${KEYCLOAK_PG_PASSWORD}'" -p "${POSTGRESQL_PORT_NUMBER:=5432}"
PGPASSWORD="${POSTGRESQL_POSTGRES_PASSWORD}" psql -d postgres -U postgres -c "create database keycloak with owner keycloak" -p "${POSTGRESQL_PORT_NUMBER:=5432}"
PGPASSWORD="${POSTGRESQL_POSTGRES_PASSWORD}" psql -d postgres -U postgres -c "revoke all privileges on database keycloak from public" -p "${POSTGRESQL_PORT_NUMBER:=5432}"
