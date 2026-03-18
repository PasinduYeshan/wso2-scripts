# ---------------------------------------------------------------------------- #
#                                 MySQL Configs                                #
# ---------------------------------------------------------------------------- #
def get_mysql_db_config(identity_db_name, shared_db_name, db_username, db_password):
    return f"""
[database.identity_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/{identity_db_name}?allowPublicKeyRetrieval=true&amp;useSSL=false"
username = "{db_username}"
password = "{db_password}"
port = "3306"

[database.shared_db]
type = "mysql"
url = "jdbc:mysql://localhost:3306/{shared_db_name}?allowPublicKeyRetrieval=true&amp;useSSL=false"
username = "{db_username}"
password = "{db_password}"
port = "3306"

"""

mysql_advanced_config = f"""
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


# ---------------------------------------------------------------------------- #
#                              PostgreSQL Configs                              #
# ---------------------------------------------------------------------------- #

def get_postgresql_db_config(identity_db_name, shared_db_name, db_username, db_password):
    return f"""
[database.identity_db]
type = "postgre"
hostname = "localhost"
name = "{identity_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "5432"

[database.shared_db]
type = "postgre"
hostname = "localhost"
name = "{shared_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "5432"

"""

postgresql_advanced_config = f"""
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
validationQuery="SELECT 1; COMMIT"
validationInterval="30000"
defaultAutoCommit=false
commitOnReturn=true

"""

# ---------------------------------------------------------------------------- #
#                                 MSSQL Configs                                #
# ---------------------------------------------------------------------------- #
def get_mssql_db_config(identity_db_name, shared_db_name, db_username, db_password):
    return f"""
[database.identity_db]
type = "mssql"
hostname = "localhost"
name = "{identity_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "1433"

[database.shared_db]
type = "mssql"
hostname = "localhost"
name = "{shared_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "1433"

"""

mssql_advanced_config = f"""

"""

def get_db2_db_config(identity_db_name, shared_db_name, db_username, db_password):
    return f"""
[database.identity_db]
type = "db2"
hostname = "localhost"
name = "{identity_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "50000"

[database.shared_db]
type = "db2"
hostname = "localhost"
name = "{shared_db_name}"
username = "{db_username}"
password = "{db_password}"
port = "50000"

"""

db2_advanced_config = f"""
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

def get_oracle_db_config(identity_db_name, shared_db_name, db_username, db_password):
    return f"""
[database.identity_db]
type = "oracle"
hostname = "localhost"
sid = "XE"
username = "{identity_db_name}"
password = "{db_password}"
port = "1521"

[database.shared_db]
type = "oracle"
hostname = "localhost"
sid = "XE"
username = "{shared_db_name}"
password = "{db_password}"
port = "1521"

"""

oracle_advanced_config = f"""
[database.identity_db.pool_options]
maxActive = "80"
maxWait = "360000"
minIdle ="5"
testOnBorrow = true
validationQuery="select 1 from dual"
validationInterval="30000"
defaultAutoCommit=false
commitOnReturn=true
 
[database.shared_db.pool_options]
maxActive = "80"
maxWait = "360000"
minIdle ="5"
testOnBorrow = true
validationQuery="select 1 from dual"
validationInterval="30000"
defaultAutoCommit=false
commitOnReturn=true

"""
