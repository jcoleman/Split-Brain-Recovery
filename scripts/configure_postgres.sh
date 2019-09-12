#!/bin/bash
set -e

cat << EOF > $PGDATA/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust

host all all all trust
local replication all trust
host replication all all trust
EOF

cat << EOF >> $PGDATA/postgresql.conf
listen_addresses = '*'

wal_level = logical
max_wal_senders = 12
max_replication_slots = 12
track_commit_timestamp = on
max_worker_processes = 12
hot_standby_feedback = on
hot_standby = on
wal_log_hints = on

logging_collector = on
log_directory = 'log'
log_filename = 'postgresql.log'
log_rotation_age = 0
log_rotation_size = 0
log_min_messages = 'warning'
log_statement = 'ddl'
wal_keep_segments = 10
archive_mode = on
#archive_command = 'mkdir -p /var/lib/postgresql/data/archive && cp %p /var/lib/postgresql/data/archive/%f'
EOF

if [ -n "$REPLICATION_HOST" ]; then
  cp $PGDATA/postgresql.conf /tmp/
  cp $PGDATA/pg_hba.conf /tmp/

  rm -rf $PGDATA/*

  echo "user `whoami`"
  ls -lah /dev/null
  /wait_for_psql.sh $REPLICATION_HOST 5432

  # TODO: Right now this isn't guaranteed to work since we
  # don't know if the other host is up yet. But docker compose
  # conveniently restarts the container when this fails...so
  # for now that is our "retry".
  pg_basebackup -h $REPLICATION_HOST -U postgres -D $PGDATA/ --wal-method=stream


  cat << EOF >> $PGDATA/recovery.conf
standby_mode          = 'on'
primary_conninfo      = 'host=$REPLICATION_HOST port=5432 user=postgres'
trigger_file = '/tmp/MasterNow'
#restore_command = 'cp /home/postgresql_wal/%f "%p"'
EOF
  cp $PGDATA/recovery.conf /tmp/postgres_recovery.conf
else
  psql -U postgres -c "create database demo"
  psql -U postgres -c 'create table items(pk serial primary key, name text)' -d demo
fi
