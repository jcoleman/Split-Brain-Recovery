#! /bin/bash

psql -h localhost -p $1 -U postgres -d demo -c "select pg_switch_wal(); checkpoint;"
