import sys

# Check if all necessary arguments are provided
if len(sys.argv) < 6:
    print("Error: Not all necessary arguments are provided.")
    sys.exit(1)

deployment_file_path = sys.argv[1]
mysql_user = sys.argv[2]
mysql_password = sys.argv[3]
identity_db_name = sys.argv[4]
shared_db_name = sys.argv[5]

# Prepare new configurations

identity_db_config = f"""
[database.identity_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/{identity_db_name}?allowPublicKeyRetrieval=true&amp;useSSL=false"
username = "{mysql_user}"
password = "{mysql_password}"
port = "3306"
"""

shared_db_config = f"""
[database.shared_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/{shared_db_name}?allowPublicKeyRetrieval=true&amp;useSSL=false"
username = "{mysql_user}"
password = "{mysql_password}"
port = "3306"
"""

advanced_config = f"""
[database.identity_db.pool_options]
maxActive = "80"
maxWait = "360000"
minIdle ="5"
testOnBorrow = true
validationQuery="SELECT 1"
validationInterval="30000"
defaultAutoCommit=false
commitOnReturn=true

[database.shared_db.pool_options]
maxActive = "80"
maxWait = "360000"
minIdle ="5"
testOnBorrow = true
validationQuery="SELECT 1"
validationInterval="30000"
defaultAutoCommit=false
commitOnReturn=true
"""

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
new_lines.append(identity_db_config)
new_lines.append(shared_db_config)
# new_lines.append(advanced_config)

# Write the updated content back to the file
with open(deployment_file_path, 'w') as file:
    file.writelines(new_lines)

print("MySQL Database configurations updated in deployment.toml.")
