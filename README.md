# WSO2 Scripts

Utility scripts for deploying, migrating, and managing WSO2 Identity Server.

## Deployment

- **[Deploy IS with SQL Databases](deploy/identity_server/README.md)** — `deploy/identity_server/configure_is_with_sql_db.sh`
  Provision a Dockerized DB (MySQL, PostgreSQL, MSSQL, Oracle, DB2), wire it into a WSO2 IS pack via `deployment.toml`, apply patches, and optionally start the server.
- **Backup / Restore DB** — `deploy/identity_server/backup_restore_db.sh`
  Snapshot and restore Identity + Shared databases for the running container. Supports named snapshots, listing, and interactive restore. See the [deploy README](deploy/identity_server/README.md#backing-up-and-restoring-databases).

## Migration

- **5.9 → 7.1 Migration** — `migration/5.9-7.1-migration.sh`
  Drives the full IS 5.9.0 → 7.1.0 upgrade, including the PostgreSQL `user_id_migration_postgresql.sql` step. Includes bundled `postgresql-42.7.0.jar` JDBC driver.
- **DB Backup Helpers** — `migration/scripts/db-backup/`
  - `mysql-db-backup.sh`
  - `postgresql-db-backup.sh`
- **Run SQL File** — `migration/scripts/run-sql-file/postgresql-sql-file.sh`
  Execute a `.sql` file against a PostgreSQL DB.

## Users

- **Bulk CSV Generator** — `users/generate_bulk_csv.sh <count> [output_file]`
  Generates a CSV (`username,givenname,emailaddress`) for bulk user import.
- **Delete IS Users** — `users/delete_is_users.sh [port]`
  SCIM2 bulk-delete users from a WSO2 IS tenant. Respects an ignore list (`admin`, etc.).
- **Delete Asgardeo Users** — `users/delete_asgardeo_users.sh`
  SCIM2 bulk-delete users from an Asgardeo org.

## API Resources

- **Management App Bootstrapper** — `api-resource/management-app.sh`
  Creates `E2E-Test-Suite-Token` application, fetches all API resources, and authorizes them on the app. Stores app ID in `app_id.txt` and resource list in `api_resources.json`.

## Helpers

- **OIDC Token Helper** — `helpers/openid_token.sh`
  Runs the authorization-code flow against a local IS, prints the authorize URL, exchanges the code, and decodes the resulting ID token.

## Logs

- **Error Log Processor** — `logs/read_error_logs.py`
  Reads a CSV query export and writes it out as a flat text log for easier reading.
