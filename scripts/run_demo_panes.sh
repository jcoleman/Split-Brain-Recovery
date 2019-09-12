#! /bin/bash

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"

while ! (docker ps | grep postgres_a_1 > /dev/null 2>&1); do
  sleep 1
done

tmux send-keys -t {top-right} "cd $PROJECT_DIR" C-m
tmux send-keys -t {top-right} "./scripts/wait_for_psql.sh localhost 5430" C-m
tmux send-keys -t {top-right} "./scripts/switch_wal_and_checkpoint.sh 5430" C-m
tmux send-keys -t {bottom-right} "./scripts/wait_for_psql.sh localhost 5430" C-m
tmux send-keys -t {bottom-right} "sleep 2 && ./scripts/long_transaction.sh" C-m
tmux send-keys -t {top-right} "sleep 3 && ./scripts/load_and_update_items.sh" C-m

primary_container_name=$(docker ps --format '{{.Names}}' | grep postgres_a_1)
replica_container_name=$(docker ps --format '{{.Names}}' | grep postgres_b_1)
tmux send-keys -t {bottom-left} "docker exec -it $primary_container_name bash" C-m
tmux send-keys -t {bottom-right} "docker exec -it $replica_container_name bash" C-m
