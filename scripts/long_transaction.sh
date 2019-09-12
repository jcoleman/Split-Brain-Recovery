#! /bin/bash

psql -h localhost -p 5430 -U postgres -d demo -c "begin; insert into items(name) values ('zip'); select pg_sleep(2); insert into items(name) values ('zap'); commit;"
