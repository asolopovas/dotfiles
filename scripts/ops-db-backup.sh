#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <DB_HOST> <DB_USER> <DB_PASS> <DB_NAME>"
    exit 1
fi

DB_HOST=$1
DB_USER=$2
DB_PASS=$3
DB_NAME=$4

OUTPUT_DIR=$(pwd)

mkdir -p "$OUTPUT_DIR"

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

is_wp_file() {
    local table=$1
    for wp_file in "${WP_FILES[@]}"; do
        if [ "$wp_file" == "$table" ]; then
            return 0
        fi
    done
    return 1
}

TABLES=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" | awk '{ print $1}' | grep -v '^Tables')

for TABLE in $TABLES; do
    ROW_COUNT=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT COUNT(*) FROM $TABLE;" | awk 'NR==2')

    if [ "$ROW_COUNT" -gt 0 ]; then
        if is_wp_file "$TABLE"; then
            PREFIX_DIR="$OUTPUT_DIR/wp"
        else
            TABLE_PREFIX=$(echo $TABLE | cut -d'_' -f1-2)
            PREFIX_DIR="$OUTPUT_DIR/$TABLE_PREFIX"
        fi
        mkdir -p "$PREFIX_DIR"
        mariadb-dump --no-create-info -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$TABLE" >"$PREFIX_DIR/$TABLE.sql"
        echo "Exported $TABLE with $ROW_COUNT rows into $PREFIX_DIR"
    else
        echo "Skipped $TABLE (no data)"
    fi
done
