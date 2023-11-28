#!/bin/bash

# ---------------------------------------------------------------------------- #
#                                    Types                                     #
# ---------------------------------------------------------------------------- #
MYSQL="mysql"
MSSQL="mssql"
ORACLE="oracle"
POSTGRESQL="postgresql"

# ---------------------------------------------------------------------------- #
#                                 User Inputs:                                 #
# ---------------------------------------------------------------------------- #
# Define the ZIP file name as a variable.
ZIP_FILE_PATH="/Users/pasindu/project/wso2is-7.0.0-beta2-SNAPSHOT.zip"
# Provide the path only if you want to unzip the zip file to a specific location.
UNZIP_DIR_PATH=""

# Define the database type as a variable.
DB_TYPE="$MYSQL"

RUN_IS="true"
RUN_IS_IN_DEBUG_MODE="false"

# ---------------------------------------------------------------------------- #
#                                Optional Inputs                               #
# ---------------------------------------------------------------------------- #
DB_USERNAME="wso2user"
DB_PASSWORD="wso2password"

IDENTITY_DB_NAME="WSO2_IDENTITY_DB"
SHARED_DB_NAME="WSO2_SHARED_DB"

MYSQL_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"
POSTGRESQL_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"
MSSQL_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"
ORACLE_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"

PATCHES_FOLDER_PATH="patches"

# Settig unzip directory path.
ZIP_FILE_BASENAME=$(basename "$ZIP_FILE_PATH")
IS_FOLDER_NAME="${ZIP_FILE_BASENAME%.zip}"
if [ -z "$UNZIP_DIR_PATH" ]; then
    UNZIP_DIR_PATH=$IS_FOLDER_NAME
    echo "UNZIP_DIR_PATH: $UNZIP_DIR_PATH"
else
    UNZIP_DIR_PATH="$UNZIP_DIR_PATH/$IS_FOLDER_NAME"
    echo "UNZIP_DIR_PATH: $UNZIP_DIR_PATH"
fi

IS_DEPLOYMENT_FILE="$UNZIP_DIR_PATH/repository/conf/deployment.toml"
IS_CONNECTOR_DIR="$UNZIP_DIR_PATH/repository/components/lib"
IS_PATCH_DIR="$UNZIP_DIR_PATH/repository/components/patches/patch9999"

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
    case $DB_TYPE in
        $MYSQL)
            cp $MYSQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $POSTGRESQL)
            cp $POSTGRESQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $MSSQL)
            cp $MSSQL_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
        $ORACLE)
            cp $ORACLE_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
    esac
}

update_deployment_toml() {
    case $DB_TYPE in
        $MYSQL)
            python3 python_scripts/mysql_deployment_toml.py "$IS_DEPLOYMENT_FILE" "$DB_USERNAME" "$DB_PASSWORD" "$IDENTITY_DB_NAME" "$SHARED_DB_NAME"
            ;;
        $POSTGRESQL)
            # Not implemented
            ;;
        $MSSQL)
            # Not implemented
            ;;
        $ORACLE)
            # Not implemented
            ;;
    esac
}

configure_environment() {
    rm -rf $UNZIP_DIR_PATH
    unzip $ZIP_FILE_PATH
    copy_jdbc_drivers
    update_deployment_toml
}

copy_patch_files() {
    mkdir -p $IS_PATCH_DIR
    cp $PATCHES_FOLDER_PATH/* $IS_PATCH_DIR
}

# ---------------------------------------------------------------------------- #
#                             Configuring Databases                            #
# ---------------------------------------------------------------------------- #
MYSQL_CONTAINER_NAME="mysql_is_200"
POSTGRESQL_CONTAINER_NAME="postgresql_is_200"
MSSQL_CONTAINER_NAME="mssql_is_200"
ORACLE_CONTAINER_NAME="oracle_is_200"

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
        ;;
    $POSTGRESQL)
        container_name="$POSTGRESQL_CONTAINER_NAME"
        db_port="$POSTGRESQL_PORT"
        ;;
    $MSSQL)
        container_name="$MSSQL_CONTAINER_NAME"
        db_port="$MSSQL_PORT"
        ;;
    $ORACLE)
        container_name="$ORACLE_CONTAINER_NAME"
        db_port="$ORACLE_PORT"
        ;;
esac

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
        echo "Error: Port $db_port is already in use. Please close the existing process."
        exit 1
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
            docker run --name "$container_name" -p 3306:3306 -e "MYSQL_ROOT_PASSWORD=$DB_PASSWORD" -d mysql:latest
            ;;
        $POSTGRESQL)
            # Not implemented
            ;;
        $MSSQL)
            # Not implemented
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
        sleep 2
    fi
}

setup_container() {
    check_and_start_container
    wait_for_container_ready
}

configure_mysql_database() {
    # Create databases
    echo "Creating databases in the MySQL container."
    # Creating user and granting permissions.
    docker exec -i $container_name mysql -u root -p$DB_PASSWORD -e "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON *.* TO '$DB_USERNAME'@'%'; FLUSH PRIVILEGES;"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $IDENTITY_DB_NAME; CREATE DATABASE $IDENTITY_DB_NAME CHARACTER SET latin1;"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS $SHARED_DB_NAME; CREATE DATABASE $SHARED_DB_NAME CHARACTER SET latin1;"

    # Execute SQL scripts
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $IDENTITY_DB_NAME < "$UNZIP_DIR_PATH/dbscripts/identity/mysql.sql"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $IDENTITY_DB_NAME < "$UNZIP_DIR_PATH/dbscripts/consent/mysql.sql"
    docker exec -i $container_name mysql -u $DB_USERNAME -p$DB_PASSWORD $SHARED_DB_NAME < "$UNZIP_DIR_PATH/dbscripts/mysql.sql"
}

configure_database() {
    setup_container
    case $DB_TYPE in
        $MYSQL)
            configure_mysql_database
            ;;
        $POSTGRESQL)
            ;;
        $MSSQL)
            ;;
        $ORACLE)
            ;;
    esac
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
run_is

