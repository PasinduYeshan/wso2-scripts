# Running WSO2 Identity Server with MySQL

This README outlines the steps to run the WSO2 Identity Server (IS) with MySQL using the `run_is_with_mysql.sh` script.

## Prerequisites

Before proceeding, ensure the following software is installed on your system:

- **MySQL or MySQL Shell**: Required for database operations.
- **Python 3**: Necessary for some scripting operations.
- **Unzip**: Needed to extract the WSO2 IS ZIP file.
- A text editor (like Vim, Nano, or VS Code) for editing script files.

## Configuration Steps

1. **Open the Script**:
   Edit the `run_is_with_mysql.sh` script in your preferred text editor. You will need to set several variables in the script to match your environment.

2. **Set File Paths**:
   - `ZIP_FILE_PATH`: Full path to your WSO2 IS ZIP file.
     ```bash
     ZIP_FILE_PATH="/Users/pasindu/project/wso2is-7.0.0-beta-SNAPSHOT.zip"
     ```
   - `UNZIP_DIR_PATH`: Directory name for extracted WSO2 IS.
     ```bash
     UNZIP_DIR_PATH="wso2is-7.0.0-beta-SNAPSHOT"
     ```

3. **MySQL Credentials**:
   - `MYSQL_USER`: MySQL username.
     ```bash
     MYSQL_USER="root"
     ```
   - `MYSQL_PASSWORD`: MySQL password.
     ```bash
     MYSQL_PASSWORD="password"
     ```

4. **Database Names**:
   - `IDENTITY_DB_NAME`: Name for the identity database.
     ```bash
     IDENTITY_DB_NAME="WSO2_IDENTITY_DB"
     ```
   - `SHARED_DB_NAME`: Name for the shared database.
     ```bash
     SHARED_DB_NAME="WSO2_SHARED_DB"
     ```

5. **Run Configuration**:
   - `RUN_IS`: `"true"` to run WSO2 IS, `"false"` to not run.
     ```bash
     RUN_IS="true"
     ```
   - `RUN_IS_IN_DEBUG_MODE`: `"true"` for debug mode, `"false"` for normal mode.
     ```bash
     RUN_IS_IN_DEBUG_MODE="false"
     ```

## Patching the IS
- Put the patch files in the `patches` directory. 
They will be copied to the `<IS_DIR>/repository/components/patches/patch9999` directory of the IS.

## Running the Script

After configuring the script, save your changes and exit the editor. To run the script, use the following command in your terminal:

```bash
./run_is_with_mysql.sh
