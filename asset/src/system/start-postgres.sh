#!/usr/bin/bash

# Export the expected environment variables
export PG_MAJOR=$(psql --version | perl -ne '/(\d+)\.\d+/ && print $1')
export PGDATA=/var/lib/postgresql/data
export PG_VERSION=$(psql --version)

# Start the postgres server entrypoint
chown postgres:postgres /var/log/postgresql-console.log
chmod 777 /var/log/postgresql-console.log
nohup docker-entrypoint.sh postgres >> /var/log/postgresql-console.log 2>&1 &
