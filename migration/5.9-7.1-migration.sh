#!/bin/bash
set -e


SOURCE_IS_DIR="/Users/pasindu/project/is-packs/older-packs/wso2is-5.9.0"
# TARGET_IS_DIR="/Users/pasindu/project/is-packs/analysis/staging/wso2is-5.10.0"
TARGET_IS_DIR="/Users/pasindu/project/is-packs/analysis/staging/wso2is-7.1.0"
SQL_FILE="user_id_migration_postgresql.sql"

# Check if source tenants directory exists
if [ ! -d "$SOURCE_IS_DIR" ]; then
    echo "❌ Source directory not found: $SOURCE_IS_DIR"
    exit 1
fi

# Check if the target directory exists
if [ ! -d "$TARGET_IS_DIR" ]; then
    echo "❌ Target IS directory not found: $TARGET_IS_DIR"
    exit 1
fi

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "❌ SQL file not found: $SQL_FILE"
    exit 1
fi

SOURCE_TENANTS_DIR="$SOURCE_IS_DIR/repository/tenants/"
SOURCE_SECURITY_DIR="$SOURCE_IS_DIR/repository/resources/security"

TARGET_REPO_DIR="$TARGET_IS_DIR/repository/"
TARGET_SECURITY_DIR="$TARGET_IS_DIR/repository/resources/security"

PRIMARY_DB="wso2_all"
PRIMARY_DB_BACKUP="wso2_all_b1"
SECONDARY_DB="wso2_all_sec"
SECONDARY_DB_BACKUP="wso2_all_sec_b1"

# Not used in this script yet.
DB_CONTAINER_NAME="postgresql_db_is_200"
DB_USER="postgres"
DB_PASSWORD="myStrongPaas42emc2"

echo "Copying db drivers to '$TARGET_IS_DIR/repository/components/lib'..."
cp "/Users/pasindu/project/wso2-repos/wso2-scripts/deploy/identity_server/drivers/postgresql-42.7.0.jar" "$TARGET_IS_DIR/repository/components/lib/"

echo "Copying tenants and security directories from '$SOURCE_IS_DIR' to '$TARGET_IS_DIR'..."
cp -r "$SOURCE_TENANTS_DIR" "$TARGET_REPO_DIR"
cp -r "$SOURCE_SECURITY_DIR"/*.jks "$TARGET_SECURITY_DIR"

bash scripts/db-backup/postgresql-db-backup.sh "$PRIMARY_DB" "$PRIMARY_DB_BACKUP"
bash scripts/db-backup/postgresql-db-backup.sh "$SECONDARY_DB" "$SECONDARY_DB_BACKUP"
bash scripts/run-sql-file/postgresql-sql-file.sh "$SQL_FILE" "$SECONDARY_DB_BACKUP"
echo "✅ Migration completed successfully from '$SECONDARY_DB' to '$SECONDARY_DB_BACKUP' and ran SQL file '$SQL_FILE'"
