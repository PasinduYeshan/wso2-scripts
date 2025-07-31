#!/bin/bash
set -e  # Exit immediately on error

# Configs
CONTAINER_NAME="postgresql_db_is_200"
DB_USER="postgres"
DB_PASSWORD="myStrongPaas42emc2"

SOURCE_DB="$1"
TARGET_DB="$2"

# Check args
if [ -z "$SOURCE_DB" ] || [ -z "$TARGET_DB" ]; then
    echo "Usage: $0 <source_db> <target_db>"
    exit 1
fi

DUMP_FILE="/tmp/${SOURCE_DB}_dump.sql"

echo "📦 Dumping source DB '$SOURCE_DB'..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  pg_dump -U "$DB_USER" -d "$SOURCE_DB" --clean -f "$DUMP_FILE"

echo "🔌 Terminating connections to '$TARGET_DB'..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d postgres -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = '$TARGET_DB' AND pid <> pg_backend_pid();
"

echo "🧼 Dropping target DB '$TARGET_DB' if it exists..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$TARGET_DB\";"

echo "🛠 Creating target DB '$TARGET_DB'..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$TARGET_DB\" OWNER \"$DB_USER\";"

echo "📥 Importing dump into '$TARGET_DB'..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d "$TARGET_DB" -f "$DUMP_FILE"

echo "🧹 Cleaning up dump file..."
docker exec "$CONTAINER_NAME" rm -f "$DUMP_FILE"

echo "✅ Database '$TARGET_DB' successfully cloned from '$SOURCE_DB'."
