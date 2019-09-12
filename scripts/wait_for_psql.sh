#! /bin/bash

while ! psql -h $1 -p $2 -U postgres --list > /dev/null 2>&1; do
  sleep 1
done
