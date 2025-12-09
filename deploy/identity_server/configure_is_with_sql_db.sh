#!/bin/bash

source scripts/helper.sh

MYSQL="mysql"
MSSQL="mssql"
ORACLE="oracle"
POSTGRESQL="postgresql"
DB2="db2"

# ---------------------------------------------------------------------------- #
#                         Reading Configuration Values                         #
# ---------------------------------------------------------------------------- #
CONFIG_FILE="config.ini"

IS_ALREADY_UNZIPPED=$(get_config_value "files" "is_already_unzipped")
ZIP_FILE_PATH=$(get_config_value "files" "zip_file_path")
IS_FOLDER_NAME=$(get_config_value "files" "is_folder_name")
UNZIP_DIR_PATH=$(get_config_value "files" "unzip_dir_path")

DB_TYPE=$(get_config_value "database" "type")
DB_PASSWORD=$(get_config_value "database" "password")
IDENTITY_DB_NAME=$(get_config_value "database" "identity_db_name")
SHARED_DB_NAME=$(get_config_value "database" "shared_db_name")
ENABLE_DB_POOLING_OPTION=$(get_config_value "database" "enable_pooling")
FORCE_CONTAINER_RECREATION=$(get_config_value "database" "force_container_recreation")

RUN_IS=$(get_config_value "server" "run_is")
RUN_IS_IN_DEBUG_MODE=$(get_config_value "server" "run_in_debug")

# ---------------------------------------------------------------------------- #
#                                Optional Inputs                               #
# ---------------------------------------------------------------------------- #
MYSQL_CONNECTOR_PATH="drivers/mysql-connector-java-8.0.30.jar"
POSTGRESQL_CONNECTOR_PATH="drivers/postgresql-42.7.0.jar"
MSSQL_CONNECTOR_PATH="drivers/mssql-jdbc-7.0.0.jre8.jar"
ORACLE_CONNECTOR_PATH="drivers/ojdbc8-23.2.0.0.jar"
DB2_CONNECTOR_PATH="drivers/db2jcc4.jar"

PATCHES_FOLDER_PATH="patches"

# If IS folder name is not given in the config file, get it from the ZIP file.
if [ -z "$IS_FOLDER_NAME" ]; then
    ZIP_FILE_BASENAME=$(basename "$ZIP_FILE_PATH")
    IS_FOLDER_NAME="${ZIP_FILE_BASENAME%.zip}"
fi

# If UNZIP_DIR_PATH is not given in the config file, use the IS folder name and create a directory in the current path.
if [ -z "$UNZIP_DIR_PATH" ]; then
    UNZIPPED_IS_PATH=$IS_FOLDER_NAME
    echo "UNZIPPED_IS_PATH: $UNZIPPED_IS_PATH"
else
    UNZIPPED_IS_PATH="$UNZIP_DIR_PATH/$IS_FOLDER_NAME"
    echo "UNZIPPED_IS_PATH: $UNZIPPED_IS_PATH"
fi

if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD="myStrongPaas42emc2"
fi

IS_DEPLOYMENT_FILE="$UNZIPPED_IS_PATH/repository/conf/deployment.toml"
IS_CONNECTOR_DIR="$UNZIPPED_IS_PATH/repository/components/lib"
IS_PATCH_DIR="$UNZIPPED_IS_PATH/repository/components/patches/patch9999"
DB_SCRIPTS_DIR="$UNZIPPED_IS_PATH/dbscripts"

CONTAINER_POSTFIX="_db_is_200"
MYSQL_CONTAINER_NAME="mysql$CONTAINER_POSTFIX"
POSTGRESQL_CONTAINER_NAME="postgresql$CONTAINER_POSTFIX"
MSSQL_CONTAINER_NAME="mssql$CONTAINER_POSTFIX"
ORACLE_CONTAINER_NAME="oracle$CONTAINER_POSTFIX"
DB2_CONTAINER_NAME="db2$CONTAINER_POSTFIX"

MYSQL_PORT="3306"
POSTGRESQL_PORT="5432"
MSSQL_PORT="1433"
ORACLE_PORT="1521"
DB2_PORT="50000"

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
        DB_USERNAME="system"
        ;;
    $DB2)
        container_name="$DB2_CONTAINER_NAME"
        db_port="$DB2_PORT"
        DB_USERNAME="db2inst1"
        ;;
esac

# If database type is db2, database names should only have characters 1-8
if [ "$DB_TYPE" = "$DB2" ]; then
    # Check if the identity database name is valid
    if [[ $IDENTITY_DB_NAME =~ ^[a-zA-Z0-9_]{1,8}$ ]]; then
        echo "Identity database name is valid."
    else
        echo "Identity database name is invalid. It should only have 1-8 characters."
        IDENTITY_DB_NAME="WSO2ISID"
        echo "Setting default identity database name: $IDENTITY_DB_NAME"
    fi

    # Check if the shared database name is valid
    if [[ $SHARED_DB_NAME =~ ^[a-zA-Z0-9_]{1,8}$ ]]; then
        echo "Shared database name is valid."
    else
        echo "Shared database name is invalid. It should only have 1-8 characters."
        SHARED_DB_NAME="WSO2ISSD"
        echo "Setting default shared database name: $SHARED_DB_NAME"
    fi
fi


# ---------------------------------------------------------------------------- #
#                                Pre-requisites                                #
# ---------------------------------------------------------------------------- #
check_prerequisites

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
        $DB2)
            cp $DB2_CONNECTOR_PATH $IS_CONNECTOR_DIR
            ;;
    esac
}

update_deployment_toml() {
    python3 python_scripts/update_deployment_toml.py \
        "$IS_DEPLOYMENT_FILE" "$DB_USERNAME" "$DB_PASSWORD" \
        "$IDENTITY_DB_NAME" "$SHARED_DB_NAME" "$ENABLE_DB_POOLING_OPTION" \
        "$DB_TYPE"
}

copy_patch_files() {
    if [ "$(ls -A $PATCHES_FOLDER_PATH)" ]; then
        echo "Copying patch files..."
        mkdir -p $IS_PATCH_DIR
        cp $PATCHES_FOLDER_PATH/* $IS_PATCH_DIR
    fi
}

remove_existing_dir_and_unzip() {
    if [ "$IS_ALREADY_UNZIPPED" = "true" ]; then
        echo "Skipping unzip. Using existing folder: $UNZIPPED_IS_PATH"
    else
        echo "Unzipping WSO2 IS from $ZIP_FILE_PATH to $UNZIP_DIR_PATH..."
        rm -rf "$UNZIPPED_IS_PATH"
        mkdir -p "$UNZIP_DIR_PATH"
        unzip -q "$ZIP_FILE_PATH" -d "$UNZIP_DIR_PATH"
    fi
}

# ---------------------------------------------------------------------------- #
#                             Configuring Databases                            #
# ---------------------------------------------------------------------------- #
source scripts/configure_db.sh

# ---------------------------------------------------------------------------- #
#                                  Run WSO2 IS                                 #
# ---------------------------------------------------------------------------- #
run_is() {
    if [ "$RUN_IS" = "true" ]; then
        checkpoint "Running WSO2 IS"
        if [ "$RUN_IS_IN_DEBUG_MODE" = "true" ]; then
            echo "Running WSO2 IS in debug mode."
            sh "$UNZIPPED_IS_PATH/bin/wso2server.sh" -debug 5005
        else
            echo "Running WSO2 IS in normal mode."
            sh "$UNZIPPED_IS_PATH/bin/wso2server.sh"
        fi
    else
        echo "WSO2 IS is configured."
    fi
}

# ---------------------------------------------------------------------------- #
#                                    Main                                      #
# ---------------------------------------------------------------------------- #
remove_existing_dir_and_unzip
copy_jdbc_drivers
update_deployment_toml
copy_patch_files
configure_database
print_db_info
run_is

