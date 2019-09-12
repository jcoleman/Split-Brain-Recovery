`pg_waldump` demo
---

1. Boot up docker.
2. Load tables.
3. Start long-running transaction.
4. Walk through how to read `pg_waldump` output.
   - Types of records (--rmgr=list)
   - Transaction IDs
   - Logical operation
   - Rel is in format `tablespace/database/relfilenode`

5. Promote replica:

    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl promote

6. Insert some new records

    # On A: To set up basic divergence.
    psql -h localhost -U postgres -d demo -c "insert into items(name) values('zig');"
    # On B: To set up basic divergence.
    psql -h localhost -U postgres -d demo -c "insert into items(name) values('zag');"
    psql -h localhost -U postgres -d demo -c "update items set name = 'zog' where name = 'zip';"

    psql -h localhost -U postgres -d demo -c "select pk, name from items order by pk;"

6. How do we figure out the diversion point?
7. Talk through custom scripting.

    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl stop

    # Handle partial segments.
    sudo -u postgres mv /var/lib/postgresql/data/pg_wal/000000010000000000000004.partial /var/lib/postgresql/data/pg_wal/000000010000000000000004

    # First, we want to capture all WAL ops done in a fuzzy window before and after the promotion.
    # pg_waldump can't follow timeline switches, so we have to do two steps here.
    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000010000000000000003 000000010000000000000004 > fuzzy_window.txt
    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000020000000000000004 >> fuzzy_window.txt

    # Determine divergence point, and then fill in below for start argument.
    grep -A1 "terminating walreceiver" /var/lib/postgresql/data/log/postgresql.log

    # Second, we need to identify all transactions committed on the replica after promotion.
    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000020000000000000004 --start <lsn> | grep COMMIT | awk '{ print $8; }' | sed 's/,//' > divergent_txids.txt

    # Third, we'll process the WAL output into relation/CTID chains.
    cat fuzzy_window.txt | ./wal-investigation/xlogdump_to_ctids.rb > fuzzy_window_relation_and_ctid_chains.csv

    # Fourth, we'll convert that information into the most recent tuple data for each CTID chain.
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl start
    cat fuzzy_window_relation_and_ctid_chains.csv  | ./wal-investigation/ctid_to_tuple_info.rb  > fuzzy_window_tuple_info.csv

    # Finally, we'll filter that information to rows inserted or updated after the divergence.
    cat fuzzy_window_tuple_info.csv | ./wal-investigation/filter_tuple_info_by_txids.rb divergent_txids.txt > divergent_tuple_data.csv


8. Demo custom scripting.

9. Rewind:

    # On B:
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl stop
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_rewind --target-pgdata=$PGDATA --source-server="host=postgres_a port=5432 user=postgres dbname=postgres"

    # TODO: recovery.conf
    ls -lah /var/lib/postgresql/data/recovery.conf
    sudo -u postgres cp /tmp/postgres_recovery.conf /var/lib/postgresql/data/recovery.conf
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl start
