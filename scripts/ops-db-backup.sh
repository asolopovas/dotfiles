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

# Define the special wp files
WP_FILES=(
  "wp_commentmeta"
  "wp_comments"
  "wp_options"
  "wp_postmeta"
  "wp_posts"
  "wp_term_relationships"
  "wp_term_taxonomy"
  "wp_termmeta"
  "wp_terms"
  "wp_usermeta"
  "wp_users"
)

# Function to check if a table is in the wp_files array
is_wp_file() {
  local table=$1
  for wp_file in "${WP_FILES[@]}"; do
    if [ "$wp_file" == "$table" ]; then
      return 0
    fi
  done
  return 1
}

# Get the list of tables in the database
TABLES=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" | awk '{ print $1}' | grep -v '^Tables' )

for TABLE in $TABLES; do
  # Check if the table has any rows
  ROW_COUNT=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM $TABLE;" | awk 'NR==2')

  if [ "$ROW_COUNT" -gt 0 ]; then
    if is_wp_file "$TABLE"; then
      PREFIX_DIR="$OUTPUT_DIR/wp"
    else
      TABLE_PREFIX=$(echo $TABLE | cut -d'_' -f1-2)
      PREFIX_DIR="$OUTPUT_DIR/$TABLE_PREFIX"
    fi
    mkdir -p "$PREFIX_DIR"
    mariadb-dump --no-create-info -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$TABLE" > "$PREFIX_DIR/$TABLE.sql"
    echo "Exported $TABLE with $ROW_COUNT rows into $PREFIX_DIR"
  else
    echo "Skipped $TABLE (no data)"
  fi
done
