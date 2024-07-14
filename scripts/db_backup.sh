#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <DB_HOST> <DB_USER> <DB_PASS> <DB_NAME>"
  exit 1
fi

# Assign arguments to variables
DB_HOST=$1
DB_USER=$2
DB_PASS=$3
DB_NAME=$4

# Set the output directory to the current working directory
OUTPUT_DIR=$(pwd)

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Get the list of tables in the database
TABLES=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" | awk '{ print $1}' | grep -v '^Tables' )

for TABLE in $TABLES; do
  # Check if the table has any rows
  ROW_COUNT=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM $TABLE;" | awk 'NR==2')

  if [ "$ROW_COUNT" -gt 0 ]; then
    # Export the table if it has rows
    mariadb-dump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$TABLE" > "$OUTPUT_DIR/$TABLE.sql"
    echo "Exported $TABLE with $ROW_COUNT rows"
  else
    echo "Skipped $TABLE (no data)"
  fi
done
