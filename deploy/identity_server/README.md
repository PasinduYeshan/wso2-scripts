# Running WSO2 Identity Server with Dockerized Databases

This README outlines the steps to run the WSO2 Identity Server (IS) with various databases (e.g., MySQL) using Docker and the `run_is_with_docker_db.sh` script.

## Prerequisites

Before proceeding, ensure the following software is installed on your system:

- **Docker**: Required for running database instances in containers.
- **Python 3**: Necessary for some scripting operations.
- **Unzip**: Needed to extract the WSO2 IS ZIP file.
- **Node.js** and npm: Essential for MSSQL database configuration, especially on ARM64 architectures.
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
# Check what is running on a specific port.
sudo lsof -i :<port_number>

# Kill the process using the port (if necessary).
sudo kill -9 <PID>
```

## Configuration Steps


### Config File
Open the `config.ini` file in your preferred text editor and set the configuration values:

```ini
[files]
zip_file_path=/Users/pasindu/project/wso2is-7.0.0-rc1-SNAPSHOT.zip
unzip_dir_path=/Users/pasindu/project/is/mssql
is_folder_name= #Zip file name without the extension is taken by default.

[database]
type=mssql # mysql, postgresql, or mssql
password=myStrongPaas42!emc2
identity_db_name=WSO2_IDENTITY_DB
shared_db_name=WSO2_SHARED_DB
enable_pooling=false
force_container_recreation=false

[server]
run_is=false
run_in_debug=false
```

### Configuration File Details
The config.ini file contains essential configurations for running the WSO2 Identity Server with Dockerized databases. Below are detailed explanations of each section and configuration option:

#### [files] Section
This section defines the file paths related to the WSO2 Identity Server (IS) ZIP file and its extraction location.

- zip_file_path: The full file path to the WSO2 IS ZIP file.
- unzip_dir_path: The directory where the IS ZIP file will be extracted. If left blank, the script uses a default directory based on the ZIP file name.
- is_folder_name: The name of the folder where IS will be unzipped. If left blank, the script assumes the folder name to be the ZIP file's name without the extension.

#### [database] Section
This section configures the database settings for the WSO2 IS.

- type: Specifies the type of database to be used. Possible values are mysql, postgresql, and mssql.
bash
- identity_db_name: The name of the identity database to be created.
- shared_db_name: The name of the shared database to be created.
- enable_pooling: Enables or disables database connection pooling.
- force_container_recreation: If set to true, existing Docker containers with the same name will be forcefully removed and recreated.

#### [server] Section
This section includes configurations related to running the WSO2 IS.

- run_is: Set to true to run the WSO2 Identity Server after configuration.
- run_in_debug: Enables debug mode if set to true.

#### Docker Database Containers
The script sets up Docker containers based on the specified database type (type in the [database] section). Ensure Docker is running on your system before executing the script.

For detailed steps on running the script and additional information, refer to the "Running the Script" section below.

Note: Update the paths, database details, and server settings as needed to match your specific setup. The configurations in `config.ini`` should be appropriately modified before running the script.


## Patching the IS
- Put the patch files in the `patches` directory. 
They will be copied to the `<IS_DIR>/repository/components/patches/patch9999` directory of the IS.

## Running the Script
After configuring the `config.ini` file, save your changes and exit the editor. To run the script, use the following command in your terminal:

```bash
chmod +x configure_is_with_sql_db.sh
./configure_is_with_sql_db.sh 
```

## Output and Logging
The script provides detailed output on the console regarding the database and IS configuration. This includes information such as the database type, container name, database port, and credentials. Additionally, this information is also logged into a file named `process_info.log` in the same directory as the script.
