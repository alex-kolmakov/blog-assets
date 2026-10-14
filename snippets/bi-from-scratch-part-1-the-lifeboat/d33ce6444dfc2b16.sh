#!/bin/bash
# copy_tables.bash — runs next to the production DB, pushes sanitized CSVs out
# (trimmed: table list shortened, remote host redacted)

DB_NAME="dbname"
DB_USER="dbuser"
REMOTE_USER="root"
REMOTE_HOST="<analytics-host>"
REMOTE_FOLDER="/tmp/data/"
LOCAL_FOLDER="/tmp/data/"
DOCKER_SERVICE="db_slave"          # read from the replica, never the primary

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
declare -a tables=("users_profile" "auth_user" "events_classevent" "transactions_transaction")

# Columns that must never leave the building
exclude_columns=("username" "password" "email" "phone" \
"raw_name" "teacher_bank_bic" "teacher_address" "staff_name" \
"teacher_bank_account_number" "teacher_bank_full_name")

joined_excludes=""
for col in "${exclude_columns[@]}"; do
    joined_excludes="${joined_excludes}'$col',"
done
exclude_sql="AND column_name NOT IN (${joined_excludes%,})"

for table in "${tables[@]}"; do
    # Ask Postgres for this table's columns, minus the excluded ones
    columns=$(docker-compose exec -T "$DOCKER_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT string_agg('\"' || column_name || '\"', ', ')
        FROM information_schema.columns
        WHERE table_name = '$table'
        $exclude_sql
    " | tr -d '[:space:]')

    if [ -z "$columns" ]; then
        echo "Warning: No columns left to export for $table after exclusions."
        continue
    fi

    docker-compose exec -T "$DOCKER_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" \
      -c "COPY (SELECT $columns FROM \"$table\") TO STDOUT WITH CSV HEADER" \
      > "$LOCAL_FOLDER$table$TIMESTAMP.csv"
    gzip -f "$LOCAL_FOLDER$table$TIMESTAMP.csv"
done

rsync -av --delete --timeout=300 "$LOCAL_FOLDER" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_FOLDER"
find "$LOCAL_FOLDER" -type f -mtime +2 -delete
