#!/bin/bash
# ---------------------------------------------------------------------------- #
#                                    Types                                     #
# ---------------------------------------------------------------------------- #
MYSQL="mysql"
MSSQL="mssql"
ORACLE="oracle"
POSTGRESQL="postgresql"

# ---------------------------------------------------------------------------- #
#                         Reading Configuration Values                         #
# ---------------------------------------------------------------------------- #
CONFIG_FILE="config.ini"

# Function to get configuration value by section and key
get_config_value() {
    local section=$1
    local key=$2
    sed -n "/^\[$section\]/, /^\[/p" "$CONFIG_FILE" | 
    grep "^$key=" | 
    cut -d'=' -f2- | 
    sed 's/#.*//' |  # Remove comments
    sed 's/^ *//; s/ *$//' |  # Trim leading and trailing spaces
    sed 's/^"//; s/"$//'  # Remove surrounding quotes
}

ZIP_FILE_PATH=$(get_config_value "files" "zip_file_path")
IS_FOLDER_NAME=$(get_config_value "files" "is_folder_name")
UNZIP_DIR_PATH=$(get_config_value "files" "unzip_dir_path")

DB_TYPE=$(get_config_value "database" "type")
# DB_USERNAME=$(get_config_value "database" "username")
DB_PASSWORD=$(get_config_value "database" "password")
IDENTITY_DB_NAME=$(get_config_value "database" "identity_db_name")
SHARED_DB_NAME=$(get_config_value "database" "shared_db_name")
ENABLE_DB_POOLING_OPTION=$(get_config_value "database" "enable_pooling")

RUN_IS=$(get_config_value "server" "run_is")
RUN_IS_IN_DEBUG_MODE=$(get_config_value "server" "run_in_debug")

# ---------------------------------------------------------------------------- #
#                                Optional Inputs                               #
# ---------------------------------------------------------------------------- #
MYSQL_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"
POSTGRESQL_CONNECTOR_PATH="drivers/postgresql-42.7.0.jar"
MSSQL_CONNECTOR_PATH="drivers/mssql-jdbc-7.0.0.jre8.jar"
ORACLE_CONNECTOR_PATH=""

PATCHES_FOLDER_PATH="patches"

# If IS folder name is not given in the config file, get it from the ZIP file.
if [ -z "$IS_FOLDER_NAME" ]; then
    ZIP_FILE_BASENAME=$(basename "$ZIP_FILE_PATH")
    IS_FOLDER_NAME="${ZIP_FILE_BASENAME%.zip}"
fi

# If UNZIP_DIR_PATH is not given in the config file, use the IS folder name and create a directory in the current path.
if [ -z "$UNZIP_DIR_PATH" ]; then
    UNZIPED_IS_PATH=$IS_FOLDER_NAME
    echo "UNZIPED_IS_PATH: $UNZIPED_IS_PATH"
else
    UNZIPED_IS_PATH="$UNZIP_DIR_PATH/$IS_FOLDER_NAME"
    echo "UNZIPED_IS_PATH: $UNZIPED_IS_PATH"
fi

IS_DEPLOYMENT_FILE="$UNZIPED_IS_PATH/repository/conf/deployment.toml"
IS_CONNECTOR_DIR="$UNZIPED_IS_PATH/repository/components/lib"
IS_PATCH_DIR="$UNZIPED_IS_PATH/repository/components/patches/patch9999"
DB_SCRIPTS_DIR="$UNZIPED_IS_PATH/dbscripts"

CONTAINER_POSTFIX="_db_is_200"
MYSQL_CONTAINER_NAME="mysql$CONTAINER_POSTFIX"
POSTGRESQL_CONTAINER_NAME="postgresql$CONTAINER_POSTFIX"
MSSQL_CONTAINER_NAME="mssql$CONTAINER_POSTFIX"
ORACLE_CONTAINER_NAME="oracle$CONTAINER_POSTFIX"

MYSQL_PORT="3306"
POSTGRESQL_PORT="5432"
MSSQL_PORT="1433"
ORACLE_PORT="1521"

container_name="$MYSQL_CONTAINER_NAME"
db_port="$MYSQL_PORT"

case $DB_TYPE in
    $MYSQL)
        container_name="$MYSQL_CONTAINER_NAME"
        db_port="$MYSQL_PORT"
        DB_USERNAME="root"
        ;;
    $POSTGRESQL)
        container_name="$POSTGRESQL_CONTAINER_NAME"
        db_port="$POSTGRESQL_PORT"
        DB_USERNAME="postgres"
        ;;
    $MSSQL)
        container_name="$MSSQL_CONTAINER_NAME"
        db_port="$MSSQL_PORT"
        DB_USERNAME="SA"
        ;;
    $ORACLE)
        container_name="$ORACLE_CONTAINER_NAME"
        db_port="$ORACLE_PORT"
        ;;
esac

# ---------------------------------------------------------------------------- #
#                                Pre-requisites                                #
# ---------------------------------------------------------------------------- #
# Check if Python 3 is installed
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is not installed or not found in PATH."
    exit 1
fi

# Check if zip is installed
if ! command -v unzip >/dev/null 2>&1; then
    echo "Error: zip is not installed or not found in PATH."
    exit 1
fi

# Check if the ZIP file exists
if [ ! -f "$ZIP_FILE_PATH" ]; then
    echo "Error: $ZIP_FILE_PATH not found."
    exit 1
fi

# Check if docker is working.
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not installed or not running."
    exit 1
fi

# ---------------------------------------------------------------------------- #
#                                Configuring IS                                #
# ---------------------------------------------------------------------------- #
copy_jdbc_drivers() {
    echo "Copying JDBC drivers... $DB_TYPE"
    case $DB_TYPE in
        $MYSQL)
            echo "Copying MySQL JDBC driver..."
            cp $MYSQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $POSTGRESQL)
            cp $POSTGRESQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $MSSQL)
            cp $MSSQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $ORACLE)
            # cp $ORACLE_CONNECTOR_PATH $IS_CONNECTOR_DIR
            # Not implemented
            ;;
    esac
}

update_deployment_toml() {
    python3 python_scripts/update_deployment_toml.py \
        "$IS_DEPLOYMENT_FILE" "$DB_USERNAME" "$DB_PASSWORD" \
        "$IDENTITY_DB_NAME" "$SHARED_DB_NAME" "$ENABLE_DB_POOLING_OPTION" \
        "$DB_TYPE"
}

configure_environment() {
    rm -rf $UNZIPED_IS_PATH
    mkdir -p $UNZIP_DIR_PATH
    unzip $ZIP_FILE_PATH -d $UNZIP_DIR_PATH
    copy_jdbc_drivers
    update_deployment_toml
}

copy_patch_files() {
    if [ "$(ls -A $PATCHES_FOLDER_PATH)" ]; then
        echo "Copying patch files..."
        mkdir -p $IS_PATCH_DIR
        cp $PATCHES_FOLDER_PATH/* $IS_PATCH_DIR
    fi
}

# ---------------------------------------------------------------------------- #
#                             Configuring Databases                            #
# ---------------------------------------------------------------------------- #

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
            docker pull mysql:latest &&
            docker run --name "$container_name" -p 3306:3306 -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD -d mysql:latest
            ;;
        $POSTGRESQL)
            docker pull postgres &&
            docker run -d -p 5432:5432 --name "$container_name" -e POSTGRES_PASSWORD=$DB_PASSWORD postgres
            ;;
        $MSSQL)
            docker pull mcr.microsoft.com/mssql/server:2019-latest &&
            docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$DB_PASSWORD" -p 1433:1433 --name $container_name -d \
            mcr.microsoft.com/mssql/server:2019-latest
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
        # Wait for the image to be pulled and the container to be created
        echo "Waiting for Docker image to be pulled..."
        until docker ps -a | grep -q "$container_name"; do
            sleep 5
        done
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

    # Creating user and granting permissions.
    docker exec -i $container_name mysql -u root -p$DB_PASSWORD -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' \
    IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON *.* TO '$DB_USERNAME'@'%'; FLUSH PRIVILEGES;"

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
    docker exec $container_name mkdir -p /dbscripts/identity
    docker exec $container_name mkdir -p /dbscripts/consent
    docker cp "$DB_SCRIPTS_DIR/identity/postgresql.sql" "$container_name:/dbscripts/identity/postgresql.sql"
    docker cp "$DB_SCRIPTS_DIR/consent/postgresql.sql" "$container_name:/dbscripts/consent/postgresql.sql"
    docker cp "$DB_SCRIPTS_DIR/postgresql.sql" "$container_name:/dbscripts/postgresql.sql"

    # Execute SQL scripts
    docker exec -i $container_name psql -U $DB_USERNAME -d $IDENTITY_DB_NAME -f "/dbscripts/identity/postgresql.sql"
    docker exec -i $container_name psql -U $DB_USERNAME -d $IDENTITY_DB_NAME -f "/dbscripts/consent/postgresql.sql"
    docker exec -i $container_name psql -U $DB_USERNAME -d $SHARED_DB_NAME -f "/dbscripts/postgresql.sql"
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
    docker exec $container_name mkdir -p /home/mssql/dbscripts/identity
    docker exec $container_name mkdir -p /home/mssql/dbscripts/consent
    docker cp "$DB_SCRIPTS_DIR/identity/mssql.sql" "$container_name:/home/mssql/dbscripts/identity/mssql.sql"
    docker cp "$DB_SCRIPTS_DIR/consent/mssql.sql" "$container_name:/home/mssql/dbscripts/consent/mssql.sql"
    docker cp "$DB_SCRIPTS_DIR/mssql.sql" "$container_name:/home/mssql/dbscripts/mssql.sql"

    # Execute SQL scripts.
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $IDENTITY_DB_NAME -i "/home/mssql/dbscripts/identity/mssql.sql"
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $IDENTITY_DB_NAME -i "/home/mssql/dbscripts/consent/mssql.sql"
    docker exec -i $container_name /opt/mssql/bin/sqlserver -S localhost -U SA -P $DB_PASSWORD -d \
    $SHARED_DB_NAME -i "/home/mssql/dbscripts/mssql.sql"
}

configure_database() {
    setup_container
    case $DB_TYPE in
        $MYSQL)
            configure_mysql_database
            ;;
        $POSTGRESQL)
            configure_postgresql_database
            ;;
        $MSSQL)
            configure_mssql_database
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


# ---------------------------------------------------------------------------- #
#                                  Run WSO2 IS                                 #
# ---------------------------------------------------------------------------- #
run_is() {
    # Run WSO2 IS
    if [ "$RUN_IS" = "true" ]; then
        # Check if RUN_IS_IN_DEBUG_MODE is set to true
        if [ "$RUN_IS_IN_DEBUG_MODE" = "true" ]; then
            echo "Running WSO2 IS in debug mode."
            sh "$UNZIP_DIR_PATH/bin/wso2server.sh" -debug 5005
        else
            echo "Running WSO2 IS in normal mode."
            sh "$UNZIP_DIR_PATH/bin/wso2server.sh"
        fi
    else
        echo "WSO2 IS is configured."
    fi
}

# ---------------------------------------------------------------------------- #
#                                    Main                                      #
# ---------------------------------------------------------------------------- #
configure_environment
copy_patch_files
configure_database
print_db_info
run_is

