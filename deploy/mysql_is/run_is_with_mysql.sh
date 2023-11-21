#!/bin/bash

# ---------------------------------------------------------------------------- #
#                                 User Inputs:                                 #
# ---------------------------------------------------------------------------- #
# Define the ZIP file name as a variable
ZIP_FILE_PATH="/Users/pasindu/project/wso2is-7.0.0-beta-SNAPSHOT.zip"
UNZIP_DIR_PATH="wso2is-7.0.0-beta-SNAPSHOT"

# MySQL credentials
MYSQL_USER="root"
MYSQL_PASSWORD="password"

IDENTITY_DB_NAME="WSO2_IDENTITY_DB"
SHARED_DB_NAME="WSO2_SHARED_DB"

RUN_IS="true"
RUN_IS_IN_DEBUG_MODE="false"

# Optional values
MYSQL_CONNECTOR_PATH="mysql-connector-java-8.0.30.jar"
PATCHES_FOLDER_PATH="patches"

# ---------------------------------------------------------------------------- #
#                                   Variables                                  #
# ---------------------------------------------------------------------------- #

IS_DEPLOYMENT_FILE="$UNZIP_DIR_PATH/repository/conf/deployment.toml"
IS_CONNECTOR_DIR="$UNZIP_DIR_PATH/repository/components/lib"
IS_PATCH_DIR="$UNZIP_DIR_PATH/repository/components/patches/patch9999"
MYSQL_TOOL=""

# ---------------------------------------------------------------------------- #
#                                Pre-requisites                                #
# ---------------------------------------------------------------------------- #


# Check if MySQL Shell is installed
if command -v mysqlsh >/dev/null 2>&1; then
    MYSQL_TOOL="mysqlsh"
elif command -v mysql >/dev/null 2>&1; then
    MYSQL_TOOL="mysql"
fi
# If neither tool is available, exit with an error
if [ -z "$MYSQL_TOOL" ]; then
    echo "Error: Neither MySQL Shell (mysqlsh) nor MySQL client (mysql) is found in PATH."
    exit 1
fi

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

# ---------------------------------------------------------------------------- #
#                                  Configuring                                 #
# ---------------------------------------------------------------------------- #
configure_environment() {
    rm -rf $UNZIP_DIR_PATH
    unzip $ZIP_FILE_PATH
    cp $MYSQL_CONNECTOR_PATH $IS_CONNECTOR_DIR

    python3 update_deployment_toml.py "$IS_DEPLOYMENT_FILE" "$MYSQL_USER" "$MYSQL_PASSWORD" "$IDENTITY_DB_NAME" "$SHARED_DB_NAME"
}

copy_patch_files() {
    mkdir -p $IS_PATCH_DIR
    cp $PATCHES_FOLDER_PATH/* $IS_PATCH_DIR
}

# ---------------------------------------------------------------------------- #
#                          Configuring MySQL Databases                         #
# ---------------------------------------------------------------------------- #
# Function to handle MySQL operations
run_mysql_operations() {
    case $MYSQL_TOOL in
        mysqlsh)
            echo "Running commands with MySQL Shell (mysqlsh)"
            mysqlsh --sql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS $IDENTITY_DB_NAME; CREATE DATABASE $IDENTITY_DB_NAME CHARACTER SET latin1;"
            mysqlsh --sql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS $SHARED_DB_NAME; CREATE DATABASE $SHARED_DB_NAME CHARACTER SET latin1;"

            mysqlsh --sql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "source $UNZIP_DIR_PATH/dbscripts/identity/mysql.sql" --database="$IDENTITY_DB_NAME"
            mysqlsh --sql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "source $UNZIP_DIR_PATH/dbscripts/consent/mysql.sql" --database="$IDENTITY_DB_NAME"
            mysqlsh --sql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "source $UNZIP_DIR_PATH/dbscripts/mysql.sql" --database="$SHARED_DB_NAME"
            ;;
        mysql)
            echo "Running commands with MySQL client (mysql)"
            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS $IDENTITY_DB_NAME; CREATE DATABASE $IDENTITY_DB_NAME CHARACTER SET latin1;"
            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "DROP DATABASE IF EXISTS $SHARED_DB_NAME; CREATE DATABASE $SHARED_DB_NAME CHARACTER SET latin1;"

            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$IDENTITY_DB_NAME" < "$UNZIP_DIR_PATH/dbscripts/identity/mysql.sql"
            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$IDENTITY_DB_NAME" < "$UNZIP_DIR_PATH/dbscripts/consent/mysql.sql"
            mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$SHARED_DB_NAME" < "$UNZIP_DIR_PATH/dbscripts/mysql.sql"
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
run_mysql_operations
run_is

