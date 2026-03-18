#!/bin/bash
set -e  # Exit immediately on error

# Configs
CONTAINER_NAME="mysql_db_is_200"
DB_USER="root"
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
docker exec "$CONTAINER_NAME" \
  mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$SOURCE_DB" \
  --single-transaction --routines --triggers --events \
  --result-file="$DUMP_FILE"

echo "🧼 Dropping target DB '$TARGET_DB' if it exists..."
docker exec "$CONTAINER_NAME" \
  mysql -u "$DB_USER" -p"$DB_PASSWORD" \
  -e "DROP DATABASE IF EXISTS \`$TARGET_DB\`;"

echo "🛠 Creating target DB '$TARGET_DB'..."
docker exec "$CONTAINER_NAME" \
  mysql -u "$DB_USER" -p"$DB_PASSWORD" \
  -e "CREATE DATABASE \`$TARGET_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "📥 Importing dump into '$TARGET_DB'..."
docker exec "$CONTAINER_NAME" \
  mysql -u "$DB_USER" -p"$DB_PASSWORD" "$TARGET_DB" \
  -e "source $DUMP_FILE"

echo "🧹 Cleaning up dump file..."
docker exec "$CONTAINER_NAME" rm -f "$DUMP_FILE"

echo "✅ Database '$TARGET_DB' successfully cloned from '$SOURCE_DB'."