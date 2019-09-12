#! /bin/bash

psql -h localhost -p 5430 -U postgres -d demo -c "insert into items(name) select i::text from generate_series(1, 10) t(i)"
psql -h localhost -p 5430 -U postgres -d demo -c "update items set name = 'foo' where name = '2'"
psql -h localhost -p 5430 -U postgres -d demo -c "update items set name = 'bar' where name = '4'"
