#!/bin/bash

PROJECT_DIR=$(pwd)

PID_FILE="$PROJECT_DIR/storage/logs/laravel_worker_pids.log"

if [[ ! -f "$PID_FILE" ]]; then
    echo "No worker PID file found in $PROJECT_DIR"
    exit 1
fi

while read pid; do
    if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping worker with PID $pid"
        kill "$pid"
    else
        echo "No process with PID $pid"
    fi
done <"$PID_FILE"

rm -f "$PID_FILE"
echo "All workers stopped."
