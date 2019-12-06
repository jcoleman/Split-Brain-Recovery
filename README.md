Presentation Guide
---

This talk is designed with a slide deck wrapped around four live demo sessions.The live demo sessions are designed to run inside the terminal multiplexer [tmux](https://github.com/tmux/tmux).

## Setup

The slide deck is in Apple's Keynote.

The live demo tmux setup can be launched like so:

1. Open a Terminal and launch tmux (to be used on the presentation display).
2. Run [`scripts/boot.sh`](scripts/boot.sh).
3. Open another Terminal window and attach to the tmux session (for use on the presenter's display).

## Live Demo Script

### Demo 1 - Discuss pg_waldump utility and output format

1. Talk about how docker setup configures a primary and replica and inserts and updates several rows in multiple transactions to provide us some demo data.
2. Show WAL segments directory.
3. Walk through how to read `pg_waldump` output.
   - Types of records (--rmgr=list)
   - Transaction IDs
   - Logical operation types
   - Rel is in format `pg_tablespace .oid/pg_database.oid/pg_class.relfilenode`

### Demo 2 - Cause a split brain

1. Promote replica:

    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl promote

2. Insert some new records to cause a logical divergence betweem nodes:

    # On A: To set up basic divergence.
    psql -h localhost -U postgres -d demo -c "insert into items(name) values('zig');"
    # On B: To set up basic divergence.
    psql -h localhost -U postgres -d demo -c "insert into items(name) values('zag');"
    psql -h localhost -U postgres -d demo -c "update items set name = 'zog' where name = 'zip';"

    # Note to audience that we should remember these rows and their changes since
    # if all goes well we should see them again.
    psql -h localhost -U postgres -d demo -c "select pk, name from items order by pk;"

### Demo 3 - Investigate split brain logical divergence

1. Show log file and promotion output:

    less /var/lib/postgresql/data/log/postgresql.log

2.  Stop server:

    # On "replica":
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl stop

    cd /

3.  Handle partial segments:
    sudo -u postgres mv /var/lib/postgresql/data/pg_wal/000000010000000000000004.partial /var/lib/postgresql/data/pg_wal/000000010000000000000004

4.  Capture all WAL ops done in a fuzzy window before and after the promotion:

    # pg_waldump can't follow timeline switches, so we have to do two steps here.
    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000010000000000000003 000000010000000000000004 > fuzzy_window.txt
    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000020000000000000004 >> fuzzy_window.txt

5. Determine divergence point to use below for start argument:

    grep -A1 "terminating walreceiver" /var/lib/postgresql/data/log/postgresql.log

6. Identify all transactions committed on the replica after promotion:

    pg_waldump --path /var/lib/postgresql/data/pg_wal 000000020000000000000004 --start <lsn> | grep COMMIT | awk '{ print $8; }' | sed 's/,//' > divergent_txids.txt

7. Process the WAL output into relation/CTID chains:

    cat fuzzy_window.txt | ./wal-investigation/xlogdump_to_ctids.rb > fuzzy_window_relation_and_ctid_chains.csv

8. Convert that information into the most recent tuple data for each CTID chain:

    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl start
    cat fuzzy_window_relation_and_ctid_chains.csv  | ./wal-investigation/ctid_to_tuple_info.rb  > fuzzy_window_tuple_info.csv

9. Filter that information to rows inserted or updated after the divergence:

    cat fuzzy_window_tuple_info.csv | ./wal-investigation/filter_tuple_info_by_txids.rb divergent_txids.txt > divergent_tuple_data.csv

### Demo 4 - Restore divergent primary into cluster

1. Rewind:

    # On primary B (former replica):
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl stop
    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_rewind --target-pgdata=$PGDATA --source-server="host=postgres_a port=5432 user=postgres dbname=postgres"

2. Fixup configuration and restart Postgres:

    # Bring back recovery.conf
    ls -lah /var/lib/postgresql/data/recovery.conf
    sudo -u postgres cp /tmp/postgres_recovery.conf /var/lib/postgresql/data/recovery.conf
    less /var/lib/postgresql/data/recovery.conf

    sudo -u postgres -E /usr/lib/postgresql/11/bin/pg_ctl start

3. Demonstrate consistency:

    # On both nodes:
    psql -U postgres -d demo -c "select pk, name from items order by pk;"

    # Test streaming replication:
    psql -U postgres -d demo

    # On primary:
    INSERT INTO items(name) VALUES ('it works!');

    # On replica:
    SELECT pk, name FROM items ORDER BY pk;
