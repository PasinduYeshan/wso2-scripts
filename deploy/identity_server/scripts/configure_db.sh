setup_mssql_js_script="scripts/setup_mssql_db.js"
MYSQL_IMAGE="mysql:latest"
POSTGRESQL_IMAGE="postgres"
IS_ARM64=false

MSSQL_IMAGE="mcr.microsoft.com/mssql/server:2019-latest"
if [[ $(uname -m) == 'arm64' ]]; then
    IS_ARM64=true
    MSSQL_IMAGE="mcr.microsoft.com/azure-sql-edge"
fi

# Check if the database is already running on the port.
is_port_in_use() {
    if lsof -i:$db_port > /dev/null; then
        return 0  # port is in use
    else
        return 1  # port is not in use
    fi
}

exit_if_port_in_use() {
    if is_port_in_use; then
        # Check if the expected container is the one using the port
        if [ "$(docker inspect -f '{{.State.Running}}' "$container_name")" = "true" ]; then
            echo "Notice: The port $db_port is already in use by the container '$container_name'."
        else
            echo "Error: Port $db_port is already in use by a different process. Please close the existing process."
            exit 1
        fi
    fi
}

# Function to wait until a Docker container is ready.
wait_for_container_ready() {
    # Check if the container exists first.
    if ! docker inspect "$container_name" > /dev/null 2>&1; then
        echo "Error: Container $container_name does not exist."
        return 1
    fi
    echo "Waiting for $container_name to become ready..."
    while [ "$(docker inspect -f '{{.State.Running}}' "$container_name")" != "true" ]; do
        sleep 5
        echo -n "Waiting ..."
    done
    echo "$container_name is ready."
}

# Create a Docker container for the database.
create_docker_container() {
    case $DB_TYPE in
        $MYSQL)
            docker pull $MYSQL_IMAGE &&
            docker run --name "$container_name" -p 3306:3306 -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD -d $MYSQL_IMAGE
            ;;
        $POSTGRESQL)
            docker pull $POSTGRESQL_IMAGE &&
            docker run -d -p 5432:5432 --name "$container_name" -e POSTGRES_PASSWORD=$DB_PASSWORD $POSTGRESQL_IMAGE
            ;;
        $MSSQL)
            docker pull $MSSQL_IMAGE &&
            docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$DB_PASSWORD" -p 1433:1433 --name $container_name -d \
            $MSSQL_IMAGE
            ;;
        $ORACLE)
            # Not implemented
            ;;
    esac
}

# Function to check if a Docker container exists and start it if it doesn't.
check_and_start_container() {
    existing_container=$(docker ps -aq -f name="$container_name")
    
    if [ -n "$existing_container" ]; then
        if [ "$(docker inspect -f '{{.State.Running}}' "$container_name")" = "false" ]; then
            exit_if_port_in_use
            echo "Starting existing Docker container: $container_name"
            docker start "$container_name"
        else
            echo "Container $container_name is already running."
        fi
    else
        exit_if_port_in_use
        echo "Creating new Docker container for $container_name. This may take a few minutes."
        create_docker_container
        echo "Docker container $container_name created."
    fi
}

setup_container() {
    check_and_start_container
    wait_for_container_ready
}

configure_mysql_database() {
    echo "Configuring MySQL database."
    sleep 10

    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $IDENTITY_DB_NAME; \
    CREATE DATABASE $IDENTITY_DB_NAME CHARACTER SET latin1;"

    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $SHARED_DB_NAME; \
    CREATE DATABASE $SHARED_DB_NAME CHARACTER SET latin1;"

    # Execute SQL scripts
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $IDENTITY_DB_NAME < \
    "$DB_SCRIPTS_DIR/identity/mysql.sql"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $IDENTITY_DB_NAME < \
    "$DB_SCRIPTS_DIR/consent/mysql.sql"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $SHARED_DB_NAME < \
    "$DB_SCRIPTS_DIR/mysql.sql"
}

configure_postgresql_database() {
    echo "Configuring PostgreSQL database."
    sleep 10

    # Create database.
    docker exec -i $container_name psql -U postgres -c "DROP DATABASE IF EXISTS \"$IDENTITY_DB_NAME\";"
    docker exec -i $container_name psql -U postgres -c "CREATE DATABASE \"$IDENTITY_DB_NAME\";"
    docker exec -i $container_name psql -U postgres -c "DROP DATABASE IF EXISTS \"$SHARED_DB_NAME\";"
    docker exec -i $container_name psql -U postgres -c "CREATE DATABASE \"$SHARED_DB_NAME\";"

    # Copy SQL scripts to the container.
    docker exec $container_name mkdir -p /tmp/dbscripts/identity
    docker exec $container_name mkdir -p /tmp/dbscripts/consent
    docker cp "$DB_SCRIPTS_DIR/identity/postgresql.sql" "$container_name:/tmp/dbscripts/identity/postgresql.sql"
    docker cp "$DB_SCRIPTS_DIR/consent/postgresql.sql" "$container_name:/tmp/dbscripts/consent/postgresql.sql"
    docker cp "$DB_SCRIPTS_DIR/postgresql.sql" "$container_name:/tmp/dbscripts/postgresql.sql"

    # Execute SQL scripts
    docker exec -i $container_name psql -U $DB_USERNAME -d $IDENTITY_DB_NAME -f "/tmp/dbscripts/identity/postgresql.sql"
    docker exec -i $container_name psql -U $DB_USERNAME -d $IDENTITY_DB_NAME -f "/tmp/dbscripts/consent/postgresql.sql"
    docker exec -i $container_name psql -U $DB_USERNAME -d $SHARED_DB_NAME -f "/tmp/dbscripts/postgresql.sql"
}

configure_mssql_database() {
    echo "Configuring MSSQL database."
    sleep 10

    # Create databases.
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -Q \
    "CREATE DATABASE $IDENTITY_DB_NAME;"
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -Q \
    "CREATE DATABASE $SHARED_DB_NAME;"

    # Copy SQL scripts to the container.
    docker exec $container_name mkdir -p /tmp/dbscripts/identity
    docker exec $container_name mkdir -p /tmp/dbscripts/consent
    docker cp "$DB_SCRIPTS_DIR/identity/mssql.sql" "$container_name:/tmp/dbscripts/identity/mssql.sql"
    docker cp "$DB_SCRIPTS_DIR/consent/mssql.sql" "$container_name:/tmp/dbscripts/consent/mssql.sql"
    docker cp "$DB_SCRIPTS_DIR/mssql.sql" "$container_name:/tmp/dbscripts/mssql.sql"

    # Execute SQL scripts.
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $IDENTITY_DB_NAME -i "/tmp/dbscripts/identity/mssql.sql"
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $IDENTITY_DB_NAME -i "/tmp/dbscripts/consent/mssql.sql"
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $SHARED_DB_NAME -i "/tmp/dbscripts/mssql.sql"
}

configure_mssql_database_arm64() {
    echo "Configuring MSSQL database."
    sleep 10

    echo "Running on ARM64, setting up databases using Node.js script"
    npm install tedious@14.7.0 --save &&
    npm i async --save &&
    node $setup_mssql_js_script "$DB_SCRIPTS_DIR" "$DB_PASSWORD" "$IDENTITY_DB_NAME" "$SHARED_DB_NAME" "$db_port"
}

configure_database() {
    checkpoint "Configuring databases"
    setup_container
    case $DB_TYPE in
        $MYSQL)
            configure_mysql_database
            ;;
        $POSTGRESQL)
            configure_postgresql_database
            ;;
        $MSSQL)
            if $IS_ARM64; then
                configure_mssql_database_arm64
            else
                configure_mssql_database
            fi
            ;;
        $ORACLE)
            ;;
    esac
}

print_db_info() {
    local log_file="process_info.log"
    
    {
        printf "\nDatabase Configuration:\n"
        printf "%-25s %s\n" "Database Type:" "$DB_TYPE"
        printf "%-25s %s\n" "Container Name:" "$container_name"
        printf "%-25s %s\n" "Database Port:" "$db_port"
        printf "%-25s %s\n" "Database Username:" "$DB_USERNAME"
        printf "%-25s %s\n" "Database Password:" "$DB_PASSWORD"
        printf "%-25s %s\n" "Identity DB Name:" "$IDENTITY_DB_NAME"
        printf "%-25s %s\n" "Shared DB Name:" "$SHARED_DB_NAME"
        printf "\n"
        printf "IS Configuration:\n"
        printf "%-25s %s\n" "Unziped IS Directory:" "$UNZIPED_IS_PATH"
    } | tee "$log_file"
}