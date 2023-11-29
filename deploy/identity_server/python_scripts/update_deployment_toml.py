import sys
from db_config_templates import (get_mysql_db_config, mysql_advanced_config, 
                                 get_postgresql_db_config, postgresql_advanced_config, 
                                 get_mssql_db_config, mssql_advanced_config)

# Check if all necessary arguments are provided.
if len(sys.argv) < 8:
    print("Error: Not all necessary arguments are provided.")
    sys.exit(1)

deployment_file_path = sys.argv[1]
db_username = sys.argv[2]
db_password = sys.argv[3]
identity_db_name = sys.argv[4]
shared_db_name = sys.argv[5]
enable_pool_options = sys.argv[6]
db_type = sys.argv[7]

# Select the appropriate configuration template
if db_type == 'postgresql':
    db_config = get_postgresql_db_config(identity_db_name, shared_db_name, db_username, db_password)
    db_advanced_config = postgresql_advanced_config
elif db_type == 'mysql':
    db_config = get_mysql_db_config(identity_db_name, shared_db_name, db_username, db_password)
    db_advanced_config = mysql_advanced_config
elif db_type == 'mssql':
    db_config = get_mssql_db_config(identity_db_name, shared_db_name, db_username, db_password)
    db_advanced_config = mssql_advanced_config
else:
    print(f"Unsupported database type: {db_type}")
    sys.exit(1)

# Read the file
with open(deployment_file_path, 'r') as file:
    lines = file.readlines()

# Remove existing configurations
new_lines = []
skip = False
for line in lines:
    if line.strip().startswith('[database.identity_db]') or line.strip().startswith('[database.shared_db]'):
        skip = True
    elif skip and line.strip().startswith('[') and line.strip().endswith(']'):
        skip = False
    if not skip:
        new_lines.append(line)

# Append new configurations
new_lines.append(db_config)
if enable_pool_options == "true":
    print("Enabling pool options for databases.")
    new_lines.append(db_advanced_config)

# Write the updated content back to the file
with open(deployment_file_path, 'w') as file:
    file.writelines(new_lines)

print("Database configurations updated in deployment.toml.")
