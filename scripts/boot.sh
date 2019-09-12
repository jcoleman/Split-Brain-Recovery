#! /bin/bash

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"

tmux split-window -v
tmux select-pane -t {top}
tmux split-window -h
tmux select-pane -t {bottom}
tmux split-window -h

cd $PROJECT_DIR; make rm

tmux send-keys -t {top-left} "cd $PROJECT_DIR; make up" C-m

tmux send-keys -t {top-right} "cd $PROJECT_DIR; ./scripts/run_demo_panes.sh" C-m
