#!/bin/bash

NUM_WORKERS=$1

if [[ -z "$NUM_WORKERS" ]]; then
    echo "Usage: $0 <number_of_workers>"
    exit 1
fi

PROJECT_DIR=$(pwd)

if [[ ! -f "$PROJECT_DIR/artisan" ]]; then
    echo "No Laravel project found in $PROJECT_DIR"
    exit 1
fi

for ((i = 1; i <= NUM_WORKERS; i++)); do
    echo "Starting worker $i in $PROJECT_DIR"
    php artisan queue:work --daemon --tries=3 >>"$PROJECT_DIR/storage/logs/worker_$i.log" 2>&1 &
    echo $! >>"$PROJECT_DIR/storage/logs/laravel_worker_pids.log"
done

echo "$NUM_WORKERS workers started."
