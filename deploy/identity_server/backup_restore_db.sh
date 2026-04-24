#!/bin/bash

source scripts/helper.sh

MYSQL="mysql"
MSSQL="mssql"
ORACLE="oracle"
POSTGRESQL="postgresql"
DB2="db2"

CONFIG_FILE="config.ini"

# ---------------------------------------------------------------------------- #
#                         Reading Configuration Values                         #
# ---------------------------------------------------------------------------- #
DB_TYPE=$(get_config_value "database" "type")
DB_VERSION=$(get_config_value "database" "version")
DB_CONTAINER_NAME=$(get_config_value "database" "container_name")
DB_PASSWORD=$(get_config_value "database" "password")
IDENTITY_DB_NAME=$(get_config_value "database" "identity_db_name")
SHARED_DB_NAME=$(get_config_value "database" "shared_db_name")

if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD="myStrongPaas42emc2"
fi

# Derive container name and credentials (mirrors configure_is_with_sql_db.sh).
CONTAINER_POSTFIX="_db_is_200"
MYSQL_CONTAINER_NAME="mysql$CONTAINER_POSTFIX"
POSTGRESQL_CONTAINER_NAME="postgresql$CONTAINER_POSTFIX"
MSSQL_CONTAINER_NAME="mssql$CONTAINER_POSTFIX"
ORACLE_CONTAINER_NAME="oracle$CONTAINER_POSTFIX"
DB2_CONTAINER_NAME="db2$CONTAINER_POSTFIX"

case $DB_TYPE in
    $MYSQL)      container_name="$MYSQL_CONTAINER_NAME";      DB_USERNAME="root"     ;;
    $POSTGRESQL) container_name="$POSTGRESQL_CONTAINER_NAME"; DB_USERNAME="postgres" ;;
    $MSSQL)      container_name="$MSSQL_CONTAINER_NAME";      DB_USERNAME="SA"       ;;
    $ORACLE)     container_name="$ORACLE_CONTAINER_NAME";      DB_USERNAME="system"   ;;
    $DB2)        container_name="$DB2_CONTAINER_NAME";         DB_USERNAME="db2inst1" ;;
esac

if [ -n "$DB_CONTAINER_NAME" ]; then
    container_name="$DB_CONTAINER_NAME"
fi

BACKUPS_DIR="db_backups"

# ---------------------------------------------------------------------------- #
#                                   Helpers                                    #
# ---------------------------------------------------------------------------- #
usage() {
    echo "Usage:"
    echo "  $0 backup [snapshot-name]    Create a backup (timestamp used if name omitted)"
    echo "  $0 restore [snapshot-name]   Restore a backup (prompts to pick one if omitted)"
    echo "  $0 list                      List all available backups"
    exit 1
}

check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not installed or not running."
        exit 1
    fi
    if ! docker ps -q -f name="^${container_name}$" | grep -q .; then
        echo "Error: Container '$container_name' is not running."
        echo "Start it first or check your config.ini."
        exit 1
    fi
}

list_backups() {
    if [ ! -d "$BACKUPS_DIR" ] || [ -z "$(ls -A "$BACKUPS_DIR" 2>/dev/null)" ]; then
        echo "No backups found in '$BACKUPS_DIR'."
        return 1
    fi
    echo "Available backups:"
    local i=1
    for dir in "$BACKUPS_DIR"/*/; do
        [ -d "$dir" ] || continue
        local db_type_info=""
        local meta="$dir/meta.txt"
        if [ -f "$meta" ]; then
            db_type_info=$(grep "^DB Type:" "$meta" | cut -d: -f2- | xargs)
        fi
        printf "  [%d] %-45s %s\n" "$i" "$(basename "$dir")" "(${db_type_info})"
        i=$((i + 1))
    done
    return 0
}

# Pick a snapshot by name or number; sets $SELECTED_SNAPSHOT.
pick_snapshot() {
    local input="$1"
    if [ -z "$input" ]; then
        list_backups || exit 1
        echo ""
        read -r -p "Enter snapshot name or number: " input
    fi

    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local i=1
        for dir in "$BACKUPS_DIR"/*/; do
            [ -d "$dir" ] || continue
            if [ "$i" -eq "$input" ]; then
                SELECTED_SNAPSHOT=$(basename "$dir")
                return
            fi
            i=$((i + 1))
        done
        echo "Error: No snapshot at index $input."
        exit 1
    else
        SELECTED_SNAPSHOT="$input"
    fi
}

# ---------------------------------------------------------------------------- #
#                              Backup Functions                                 #
# ---------------------------------------------------------------------------- #
backup_mysql() {
    local dir="$1"
    echo "Dumping MySQL databases..."
    docker exec "$container_name" mysqldump -u "$DB_USERNAME" -p"$DB_PASSWORD" \
        --single-transaction "$IDENTITY_DB_NAME" > "$dir/identity_db.sql"
    docker exec "$container_name" mysqldump -u "$DB_USERNAME" -p"$DB_PASSWORD" \
        --single-transaction "$SHARED_DB_NAME" > "$dir/shared_db.sql"
}

backup_postgresql() {
    local dir="$1"
    echo "Dumping PostgreSQL databases..."
    docker exec "$container_name" pg_dump -U "$DB_USERNAME" "$IDENTITY_DB_NAME" > "$dir/identity_db.sql"
    docker exec "$container_name" pg_dump -U "$DB_USERNAME" "$SHARED_DB_NAME" > "$dir/shared_db.sql"
}

backup_mssql() {
    local dir="$1"
    echo "Backing up MSSQL databases..."
    docker exec "$container_name" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U "$DB_USERNAME" -P "$DB_PASSWORD" \
        -Q "BACKUP DATABASE [$IDENTITY_DB_NAME] TO DISK='/tmp/identity_db.bak' WITH FORMAT, INIT;"
    docker exec "$container_name" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U "$DB_USERNAME" -P "$DB_PASSWORD" \
        -Q "BACKUP DATABASE [$SHARED_DB_NAME] TO DISK='/tmp/shared_db.bak' WITH FORMAT, INIT;"
    docker cp "$container_name:/tmp/identity_db.bak" "$dir/identity_db.bak"
    docker cp "$container_name:/tmp/shared_db.bak" "$dir/shared_db.bak"
}

backup_oracle() {
    local dir="$1"
    echo "Exporting Oracle schemas with Data Pump..."
    # DATA_PUMP_DIR in gvenzl/oracle-xe points to /opt/oracle/admin/XE/dpdump/
    docker exec "$container_name" bash -c \
        "expdp system/$DB_PASSWORD@//localhost:1521/XE \
        schemas=$IDENTITY_DB_NAME \
        directory=DATA_PUMP_DIR \
        dumpfile=identity_db.dmp \
        logfile=identity_db_exp.log \
        reuse_dumpfiles=yes" 2>&1
    docker exec "$container_name" bash -c \
        "expdp system/$DB_PASSWORD@//localhost:1521/XE \
        schemas=$SHARED_DB_NAME \
        directory=DATA_PUMP_DIR \
        dumpfile=shared_db.dmp \
        logfile=shared_db_exp.log \
        reuse_dumpfiles=yes" 2>&1
    docker cp "$container_name:/opt/oracle/admin/XE/dpdump/identity_db.dmp" "$dir/identity_db.dmp"
    docker cp "$container_name:/opt/oracle/admin/XE/dpdump/shared_db.dmp" "$dir/shared_db.dmp"
}

backup_db2() {
    local dir="$1"
    echo "Backing up DB2 databases..."
    mkdir -p "$dir/identity_db" "$dir/shared_db"
    docker exec "$container_name" bash -c "mkdir -p /tmp/db2_bak_identity /tmp/db2_bak_shared"
    docker exec "$container_name" su - db2inst1 -c \
        "db2 force applications all; sleep 5; \
         db2 backup db $IDENTITY_DB_NAME to /tmp/db2_bak_identity"
    docker exec "$container_name" su - db2inst1 -c \
        "db2 backup db $SHARED_DB_NAME to /tmp/db2_bak_shared"
    docker cp "$container_name:/tmp/db2_bak_identity/." "$dir/identity_db/"
    docker cp "$container_name:/tmp/db2_bak_shared/." "$dir/shared_db/"
}

# ---------------------------------------------------------------------------- #
#                             Restore Functions                                 #
# ---------------------------------------------------------------------------- #
restore_mysql() {
    local dir="$1"
    echo "Restoring MySQL databases..."
    docker exec "$container_name" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" -e \
        "DROP DATABASE IF EXISTS \`$IDENTITY_DB_NAME\`;
         CREATE DATABASE \`$IDENTITY_DB_NAME\` CHARACTER SET latin1;"
    docker exec "$container_name" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" -e \
        "DROP DATABASE IF EXISTS \`$SHARED_DB_NAME\`;
         CREATE DATABASE \`$SHARED_DB_NAME\` CHARACTER SET latin1;"
    docker exec -i "$container_name" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" \
        "$IDENTITY_DB_NAME" < "$dir/identity_db.sql"
    docker exec -i "$container_name" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" \
        "$SHARED_DB_NAME" < "$dir/shared_db.sql"
}

restore_postgresql() {
    local dir="$1"
    echo "Restoring PostgreSQL databases..."
    docker exec "$container_name" psql -U "$DB_USERNAME" \
        -c "DROP DATABASE IF EXISTS \"$IDENTITY_DB_NAME\"; CREATE DATABASE \"$IDENTITY_DB_NAME\";"
    docker exec "$container_name" psql -U "$DB_USERNAME" \
        -c "DROP DATABASE IF EXISTS \"$SHARED_DB_NAME\"; CREATE DATABASE \"$SHARED_DB_NAME\";"
    docker exec -i "$container_name" psql -U "$DB_USERNAME" -d "$IDENTITY_DB_NAME" < "$dir/identity_db.sql"
    docker exec -i "$container_name" psql -U "$DB_USERNAME" -d "$SHARED_DB_NAME" < "$dir/shared_db.sql"
}

restore_mssql() {
    local dir="$1"
    echo "Restoring MSSQL databases..."
    docker cp "$dir/identity_db.bak" "$container_name:/tmp/identity_db.bak"
    docker cp "$dir/shared_db.bak" "$container_name:/tmp/shared_db.bak"
    docker exec "$container_name" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U "$DB_USERNAME" -P "$DB_PASSWORD" -Q "
        IF DB_ID('$IDENTITY_DB_NAME') IS NOT NULL
            ALTER DATABASE [$IDENTITY_DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        RESTORE DATABASE [$IDENTITY_DB_NAME] FROM DISK='/tmp/identity_db.bak' WITH REPLACE;
        ALTER DATABASE [$IDENTITY_DB_NAME] SET MULTI_USER;"
    docker exec "$container_name" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U "$DB_USERNAME" -P "$DB_PASSWORD" -Q "
        IF DB_ID('$SHARED_DB_NAME') IS NOT NULL
            ALTER DATABASE [$SHARED_DB_NAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        RESTORE DATABASE [$SHARED_DB_NAME] FROM DISK='/tmp/shared_db.bak' WITH REPLACE;
        ALTER DATABASE [$SHARED_DB_NAME] SET MULTI_USER;"
}

restore_oracle() {
    local dir="$1"
    echo "Importing Oracle schemas with Data Pump..."
    docker cp "$dir/identity_db.dmp" "$container_name:/opt/oracle/admin/XE/dpdump/identity_db.dmp"
    docker cp "$dir/shared_db.dmp" "$container_name:/opt/oracle/admin/XE/dpdump/shared_db.dmp"
    # Drop and recreate users so impdp starts clean.
    docker exec -i "$container_name" sqlplus -s /nolog <<EOF
CONNECT system/$DB_PASSWORD
WHENEVER SQLERROR CONTINUE;
DROP USER $IDENTITY_DB_NAME CASCADE;
DROP USER $SHARED_DB_NAME CASCADE;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
CREATE USER $IDENTITY_DB_NAME IDENTIFIED BY $DB_PASSWORD DEFAULT TABLESPACE users;
CREATE USER $SHARED_DB_NAME IDENTIFIED BY $DB_PASSWORD DEFAULT TABLESPACE users;
GRANT CONNECT, RESOURCE TO $IDENTITY_DB_NAME;
GRANT CONNECT, RESOURCE TO $SHARED_DB_NAME;
ALTER USER $IDENTITY_DB_NAME QUOTA UNLIMITED ON users;
ALTER USER $SHARED_DB_NAME QUOTA UNLIMITED ON users;
GRANT ALL PRIVILEGES TO $IDENTITY_DB_NAME;
GRANT ALL PRIVILEGES TO $SHARED_DB_NAME;
EXIT;
EOF
    docker exec "$container_name" bash -c \
        "impdp system/$DB_PASSWORD@//localhost:1521/XE \
        schemas=$IDENTITY_DB_NAME \
        directory=DATA_PUMP_DIR \
        dumpfile=identity_db.dmp \
        logfile=identity_db_imp.log \
        table_exists_action=replace" 2>&1
    docker exec "$container_name" bash -c \
        "impdp system/$DB_PASSWORD@//localhost:1521/XE \
        schemas=$SHARED_DB_NAME \
        directory=DATA_PUMP_DIR \
        dumpfile=shared_db.dmp \
        logfile=shared_db_imp.log \
        table_exists_action=replace" 2>&1
}

restore_db2() {
    local dir="$1"
    echo "Restoring DB2 databases..."
    docker exec "$container_name" bash -c "mkdir -p /tmp/db2_rst_identity /tmp/db2_rst_shared"
    docker cp "$dir/identity_db/." "$container_name:/tmp/db2_rst_identity/"
    docker cp "$dir/shared_db/." "$container_name:/tmp/db2_rst_shared/"
    docker exec "$container_name" su - db2inst1 -c \
        "db2 force applications all; sleep 10; \
         db2 drop db $IDENTITY_DB_NAME; \
         db2 drop db $SHARED_DB_NAME" || true
    docker exec "$container_name" su - db2inst1 -c \
        "db2 restore db $IDENTITY_DB_NAME from /tmp/db2_rst_identity"
    docker exec "$container_name" su - db2inst1 -c \
        "db2 restore db $SHARED_DB_NAME from /tmp/db2_rst_shared"
}

# ---------------------------------------------------------------------------- #
#                               Main Operations                                #
# ---------------------------------------------------------------------------- #
do_backup() {
    local label="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
    local snapshot_name
    if [ -z "$label" ]; then
        snapshot_name="$timestamp"
    else
        snapshot_name="${timestamp}_${label// /_}"
    fi

    local snapshot_dir="$BACKUPS_DIR/$snapshot_name"
    mkdir -p "$snapshot_dir"

    cat > "$snapshot_dir/meta.txt" <<EOF
Snapshot: $snapshot_name
Date: $(date)
DB Type: $DB_TYPE
Container: $container_name
Identity DB: $IDENTITY_DB_NAME
Shared DB: $SHARED_DB_NAME
EOF

    checkpoint "Backing up databases to '$snapshot_name'"
    case $DB_TYPE in
        $MYSQL)      backup_mysql      "$snapshot_dir" ;;
        $POSTGRESQL) backup_postgresql "$snapshot_dir" ;;
        $MSSQL)      backup_mssql      "$snapshot_dir" ;;
        $ORACLE)     backup_oracle     "$snapshot_dir" ;;
        $DB2)        backup_db2        "$snapshot_dir" ;;
        *)
            echo "Error: Unsupported DB type '$DB_TYPE'."
            rm -rf "$snapshot_dir"
            exit 1
            ;;
    esac

    echo ""
    echo "Backup complete: $snapshot_dir"
}

do_restore() {
    local input="$1"
    pick_snapshot "$input"

    local snapshot_dir="$BACKUPS_DIR/$SELECTED_SNAPSHOT"
    if [ ! -d "$snapshot_dir" ]; then
        echo "Error: Snapshot '$SELECTED_SNAPSHOT' not found in '$BACKUPS_DIR'."
        exit 1
    fi

    echo ""
    echo "Snapshot : $SELECTED_SNAPSHOT"
    if [ -f "$snapshot_dir/meta.txt" ]; then
        cat "$snapshot_dir/meta.txt"
    fi
    echo ""
    read -r -p "This will overwrite the current databases. Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Restore cancelled."; exit 0; }

    checkpoint "Restoring databases from '$SELECTED_SNAPSHOT'"
    case $DB_TYPE in
        $MYSQL)      restore_mysql      "$snapshot_dir" ;;
        $POSTGRESQL) restore_postgresql "$snapshot_dir" ;;
        $MSSQL)      restore_mssql      "$snapshot_dir" ;;
        $ORACLE)     restore_oracle     "$snapshot_dir" ;;
        $DB2)        restore_db2        "$snapshot_dir" ;;
        *)
            echo "Error: Unsupported DB type '$DB_TYPE'."
            exit 1
            ;;
    esac

    echo ""
    echo "Restore complete from: $snapshot_dir"
}

# ---------------------------------------------------------------------------- #
#                                    Main                                      #
# ---------------------------------------------------------------------------- #
CMD="${1:-}"
ARG="${2:-}"

case "$CMD" in
    backup)
        check_docker
        do_backup "$ARG"
        ;;
    restore)
        check_docker
        do_restore "$ARG"
        ;;
    list)
        list_backups
        ;;
    *)
        usage
        ;;
esac
