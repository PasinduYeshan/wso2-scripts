# Running WSO2 Identity Server with Dockerized Databases

This README outlines the steps to run the WSO2 Identity Server (IS) with various databases (e.g., MySQL) using Docker and the `run_is_with_docker_db.sh` script.

## Prerequisites

Before proceeding, ensure the following software is installed on your system:

- **Docker**: Required for running database instances in containers.
- **Python 3**: Necessary for some scripting operations.
- **Unzip**: Needed to extract the WSO2 IS ZIP file.
- A text editor (like Vim, Nano, or VS Code) for editing configuration files.

## Port Availability Check

Before running the script, ensure the following ports are not being used by other services:

- **9443** - WSO2 IS
- **3306** - MySQL
- **1433** - MSSQL
- **1521** - Oracle
- **5432** - PostgreSQL

To check and free up these ports, use:

```bash
# Check what is running on a specific port
sudo lsof -i :<port_number>

# Kill the process using the port (if necessary)
sudo kill -9 <PID>
```

## Configuration Steps

Open the `config.ini` file in your preferred text editor and set the configuration values:

```ini
[files]
zip_file_path=/Users/pasindu/project/wso2is-7.0.0-beta2-SNAPSHOT.zip
is_folder_name=wso2is-7.0.0-beta2-SNAPSHOT #Usually the zip file name without the extension
unzip_dir_path=/Users/pasindu/project/is/mysql #The directory where the IS will be unzipped

# mysql, mssql, oracle, or postgresql
[database]
type=mysql # mysql, mssql, oracle, or postgresql
username=wso2user
password=wso2password
identity_db_name=WSO2_IDENTITY_DB
shared_db_name=WSO2_SHARED_DB
enable_pooling=false

[server]
run_is=true
run_in_debug=false
```

Update the paths, database details, and server settings as needed.

Docker Database Containers:
The script will automatically set up Docker containers for the specified database type. Ensure Docker is running on your system.


## Patching the IS
- Put the patch files in the `patches` directory. 
They will be copied to the `<IS_DIR>/repository/components/patches/patch9999` directory of the IS.

## Running the Script

After configuring the `config.ini` file, save your changes and exit the editor. To run the script, use the following command in your terminal:

```bash
./configure_is_with_sql_db.sh
```

## Notes
- MSSQL and Oracle databases are not tested with the script.
