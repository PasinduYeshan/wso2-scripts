#!/bin/bash
set -e

# Config
CONTAINER_NAME="postgresql_db_is_200"
DB_USER="postgres"
DB_PASSWORD="myStrongPaas42emc2"

SQL_FILE_PATH="$1"
TARGET_DB="$2"

# Validate input
if [ -z "$SQL_FILE_PATH" ] || [ -z "$TARGET_DB" ]; then
    echo "Usage: $0 <sql_file_path> <target_database>"
    exit 1
fi

if [ ! -f "$SQL_FILE_PATH" ]; then
    echo "❌ SQL file not found: $SQL_FILE_PATH"
    exit 1
fi

# Copy SQL file into container
BASENAME=$(basename "$SQL_FILE_PATH")
CONTAINER_SQL_PATH="/tmp/$BASENAME"

echo "📤 Copying SQL file to container..."
docker cp "$SQL_FILE_PATH" "$CONTAINER_NAME:$CONTAINER_SQL_PATH"

# Run SQL file
echo "🚀 Executing SQL file on DB '$TARGET_DB'..."
docker exec -e PGPASSWORD=$DB_PASSWORD "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d "$TARGET_DB" -f "$CONTAINER_SQL_PATH"

# Optional cleanup
echo "🧹 Cleaning up..."
docker exec "$CONTAINER_NAME" rm -f "$CONTAINER_SQL_PATH"

echo "✅ SQL file executed successfully on '$TARGET_DB'."
