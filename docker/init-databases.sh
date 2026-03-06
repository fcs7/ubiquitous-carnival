#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE evolution;
    GRANT ALL PRIVILEGES ON DATABASE evolution TO $POSTGRES_USER;
EOSQL
