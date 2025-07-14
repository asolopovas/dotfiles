#!/bin/bash

find . -type f -regex ".*-[0-9]+x[0-9]+\.jpg" | while read -r file; do
  original_file="${file%-*}.jpg"
  if [ -f "$original_file" ]; then
    rm -f "$file"
  fi
done
